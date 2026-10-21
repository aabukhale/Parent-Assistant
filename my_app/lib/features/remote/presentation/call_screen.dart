import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';
import '../application/call_engine.dart';
import '../data/remote_repository.dart';

/// Full-screen voice/video call. Always shows what is live (camera,
/// microphone) and one large red "End call" button.
class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
    required this.repo,
    required this.session,
    required this.isOfferer,
    required this.otherName,
  });

  final RemoteRepository repo;
  final RemoteSession session;
  final bool isOfferer;
  final String otherName;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late final CallEngine _engine = CallEngine(
    repo: widget.repo,
    sessionId: widget.session.id,
    isOfferer: widget.isOfferer,
    video: widget.session.isVideo,
  )..addListener(_changed);

  @override
  void initState() {
    super.initState();
    _engine.start();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (_engine.phase == CallPhase.ended) {
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  @override
  void dispose() {
    _engine
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final e = _engine;
    final status = switch (e.phase) {
      CallPhase.starting || CallPhase.connecting => l.callConnecting,
      CallPhase.connected => l.callConnected,
      CallPhase.ended => l.callEnded,
      CallPhase.failed => l.callFailed,
      CallPhase.noPermission => l.callPermission,
    };
    final live =
        e.phase == CallPhase.connecting || e.phase == CallPhase.connected;

    return PopScope(
      // Leaving the screen ends the call — nothing keeps running unseen.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && live) e.hangUp();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              if (widget.session.isVideo)
                Positioned.fill(
                  child: RTCVideoView(
                    e.remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                )
              else
                Center(
                  child: Icon(
                    Icons.person_rounded,
                    size: 120,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              Positioned(
                top: AppSpacing.lg,
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                child: Column(
                  children: [
                    Text(
                      widget.otherName,
                      style: context.type.headlineSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        status,
                        textAlign: TextAlign.center,
                        style: context.type.bodyLarge?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    if (!e.relayConfigured && e.phase == CallPhase.connecting)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          l.callRelayMissing,
                          textAlign: TextAlign.center,
                          style: context.type.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      alignment: WrapAlignment.center,
                      children: [
                        if (live && e.micOn)
                          _LiveChip(
                            icon: Icons.mic_rounded,
                            label: l.callMicLive,
                          ),
                        if (live && widget.session.isVideo && e.cameraOn)
                          _LiveChip(
                            icon: Icons.videocam_rounded,
                            label: l.callCameraLive,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.session.isVideo)
                PositionedDirectional(
                  end: AppSpacing.lg,
                  bottom: 140,
                  width: 110,
                  height: 160,
                  child: ClipRRect(
                    borderRadius: AppRadii.mediumAll,
                    child: RTCVideoView(e.localRenderer, mirror: true),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: AppSpacing.xl,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _RoundButton(
                      icon: e.micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                      label: e.micOn ? l.callMute : l.callUnmute,
                      onTap: live ? e.toggleMic : null,
                    ),
                    _RoundButton(
                      icon: Icons.call_end_rounded,
                      label: l.callEnd,
                      color: const Color(0xFFD32F2F),
                      size: 76,
                      onTap: () async {
                        await e.hangUp();
                        if (context.mounted) Navigator.of(context).maybePop();
                      },
                    ),
                    if (widget.session.isVideo)
                      _RoundButton(
                        icon: e.cameraOn
                            ? Icons.videocam_rounded
                            : Icons.videocam_off_rounded,
                        label: e.cameraOn ? l.callCameraOff : l.callCameraOn,
                        onTap: live ? e.toggleCamera : null,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 18, color: Colors.white),
    label: Text(label, style: const TextStyle(color: Colors.white)),
    backgroundColor: const Color(0xFF2E7D32),
    side: BorderSide.none,
  );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.size = 60,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: color ?? Colors.white24,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: Colors.white, size: size * 0.45),
            ),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
    ],
  );
}
