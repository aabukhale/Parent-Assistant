import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../data/remote_repository.dart';

enum CallPhase { starting, connecting, connected, ended, failed, noPermission }

/// A WebRTC voice/video call over Mamily's authenticated signalling.
///
/// * The adult always creates the offer; the child answers. Either side can
///   hang up; the server also ends the session on timeout/revocation, which
///   this engine notices on the next poll and stops media.
/// * Media is peer-to-peer (DTLS-SRTP encrypted by WebRTC). Without a TURN
///   relay some networks cannot connect; [relayConfigured] lets the UI say so.
/// * Camera/mic are requested only when the call starts (after the child
///   accepted), and are released on every exit path.
class CallEngine extends ChangeNotifier {
  CallEngine({
    required this.repo,
    required this.sessionId,
    required this.isOfferer,
    required this.video,
  });

  final RemoteRepository repo;
  final String sessionId;
  final bool isOfferer;
  final bool video;

  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();

  CallPhase phase = CallPhase.starting;
  bool micOn = true;
  bool cameraOn = true;
  bool relayConfigured = true;
  String? endReason;

  RTCPeerConnection? _pc;
  MediaStream? _local;
  Timer? _poll;
  int _after = 0;
  bool _remoteSet = false;
  bool _disposed = false;
  final _pendingIce = <RTCIceCandidate>[];

  Future<void> start() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    try {
      _local = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': video ? {'facingMode': 'user'} : false,
      });
    } catch (_) {
      _set(CallPhase.noPermission);
      await hangUp();
      return;
    }
    cameraOn = video;
    localRenderer.srcObject = _local;

    try {
      final ice = await repo.ice(sessionId);
      relayConfigured = ice.relayConfigured;
      _pc = await createPeerConnection({
        'iceServers': ice.servers,
        'sdpSemantics': 'unified-plan',
      });
    } catch (_) {
      _set(CallPhase.failed);
      await _stopMedia();
      return;
    }
    final pc = _pc!;
    for (final t in _local!.getTracks()) {
      await pc.addTrack(t, _local!);
    }
    pc.onIceCandidate = (c) {
      if (c.candidate == null) return;
      repo.signal(sessionId, 'ice', c.toMap() as Map<String, dynamic>).ignore();
    };
    pc.onTrack = (e) {
      if (e.streams.isNotEmpty) {
        remoteRenderer.srcObject = e.streams.first;
        _set(CallPhase.connected);
      }
    };
    pc.onConnectionState = (s) {
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _set(CallPhase.connected);
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _set(CallPhase.failed);
      }
    };

    _set(CallPhase.connecting);
    if (isOfferer) {
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      await repo.signal(sessionId, 'offer', {
        'sdp': offer.sdp,
        'type': offer.type,
      });
    }
    _poll = Timer.periodic(const Duration(milliseconds: 800), (_) => _tick());
  }

  bool _ticking = false;

  Future<void> _tick() async {
    // A slow request or setRemoteDescription must not let the next tick
    // re-handle the same offer.
    if (_disposed || _ticking) return;
    _ticking = true;
    try {
      final r = await repo.poll(sessionId, _after);
      if (!r.session.isActive) {
        endReason = r.session.endReason;
        await _finish();
        return;
      }
      for (final s in r.signals) {
        _after = s.id;
        try {
          await _handle(s);
        } catch (_) {
          // An offer/answer the phone can't use means no call: say so
          // instead of showing "Connecting…" forever. A bad ICE candidate
          // is harmless, others may still work.
          if (s.type == 'offer' || s.type == 'answer') {
            _set(CallPhase.failed);
          }
        }
      }
    } catch (_) {
      // Transient network error: keep polling; the server's idle timeout
      // ends the session if this side really disappeared.
    } finally {
      _ticking = false;
    }
  }

  Future<void> _handle(RemoteSignal s) async {
    final pc = _pc;
    if (pc == null) return;
    switch (s.type) {
      case 'offer' when !isOfferer:
        await pc.setRemoteDescription(
          RTCSessionDescription(s.payload['sdp'] as String?, 'offer'),
        );
        _remoteSet = true;
        await _flushIce();
        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        await repo.signal(sessionId, 'answer', {
          'sdp': answer.sdp,
          'type': answer.type,
        });
      case 'answer' when isOfferer:
        await pc.setRemoteDescription(
          RTCSessionDescription(s.payload['sdp'] as String?, 'answer'),
        );
        _remoteSet = true;
        await _flushIce();
      case 'ice':
        final c = RTCIceCandidate(
          s.payload['candidate'] as String?,
          s.payload['sdpMid'] as String?,
          (s.payload['sdpMLineIndex'] as num?)?.toInt(),
        );
        if (_remoteSet) {
          await pc.addCandidate(c);
        } else {
          _pendingIce.add(c);
        }
    }
  }

  Future<void> _flushIce() async {
    for (final c in _pendingIce) {
      await _pc?.addCandidate(c);
    }
    _pendingIce.clear();
  }

  void toggleMic() {
    micOn = !micOn;
    for (final t in _local?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = micOn;
    }
    notifyListeners();
  }

  void toggleCamera() {
    if (!video) return;
    cameraOn = !cameraOn;
    for (final t in _local?.getVideoTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = cameraOn;
    }
    notifyListeners();
  }

  /// End for both sides.
  Future<void> hangUp() async {
    try {
      await repo.end(sessionId);
    } catch (_) {}
    await _finish();
  }

  Future<void> _finish() async {
    _poll?.cancel();
    await _stopMedia();
    if (phase != CallPhase.noPermission && phase != CallPhase.failed) {
      _set(CallPhase.ended);
    }
  }

  Future<void> _stopMedia() async {
    try {
      for (final t in _local?.getTracks() ?? const <MediaStreamTrack>[]) {
        await t.stop();
      }
      await _local?.dispose();
      await _pc?.close();
    } catch (_) {}
    _local = null;
    _pc = null;
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
  }

  void _set(CallPhase p) {
    phase = p;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _stopMedia();
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }
}
