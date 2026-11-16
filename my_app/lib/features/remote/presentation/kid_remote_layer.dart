import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/deep_links.dart';
import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';
import '../../kid/presentation/kid_feedback.dart';
import '../data/remote_repository.dart';
import 'call_screen.dart';

/// Live remote session for this child (requested or active), refreshed while
/// Mamily is in the foreground and whenever a push "remote_session" signal
/// arrives. Null when there is none.
class KidRemoteController extends StateNotifier<RemoteSession?> {
  KidRemoteController(this._repo) : super(null);

  final RemoteRepository _repo;
  Timer? _timer;

  void startPolling() {
    _timer ??= Timer.periodic(const Duration(seconds: 8), (_) => refresh());
    refresh();
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() async {
    try {
      final s = await _repo.live();
      if (mounted) state = s;
    } catch (_) {}
  }

  Future<RemoteSession?> accept() async {
    final s = state;
    if (s == null) return null;
    final r = await _repo.accept(s.id);
    if (mounted) state = r.isLive ? r : null;
    return r;
  }

  Future<void> decline() async {
    final s = state;
    if (s == null) return;
    try {
      await _repo.decline(s.id);
    } catch (_) {}
    if (mounted) state = null;
  }

  Future<void> end() async {
    final s = state;
    if (s == null) return;
    try {
      await _repo.end(s.id);
    } catch (_) {}
    if (mounted) state = null;
  }

  /// Child asks a grown-up for help or calls them.
  Future<RemoteSession> ask(String kind, String adultId) async {
    final s = await _repo.request(kind, adultId: adultId);
    if (mounted) state = s;
    return s;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}

final kidRemoteProvider =
    StateNotifierProvider.autoDispose<KidRemoteController, RemoteSession?>(
      (ref) => KidRemoteController(ref.watch(kidRemoteRepositoryProvider)),
    );

/// Wraps the child app. Shows incoming requests, keeps an always-visible
/// banner (with Stop) while a session is active, uploads snapshots of the
/// Mamily screen during in-app help and draws the parent's pointer.
class KidRemoteLayer extends ConsumerStatefulWidget {
  const KidRemoteLayer({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KidRemoteLayer> createState() => _KidRemoteLayerState();
}

class _KidRemoteLayerState extends ConsumerState<KidRemoteLayer>
    with WidgetsBindingObserver {
  final _boundary = GlobalKey();
  String? _promptedFor;
  String? _callOpenedFor;
  Timer? _frameTimer;
  Timer? _signalTimer;
  int _after = 0;
  Offset? _pointer;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(kidRemoteProvider.notifier).startPolling(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    _foreground = s == AppLifecycleState.resumed;
    final c = ref.read(kidRemoteProvider.notifier);
    if (_foreground) {
      c.startPolling();
    } else {
      // Nothing is captured while Mamily isn't on screen.
      c.stopPolling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopHelp();
    super.dispose();
  }

  void _onSession(RemoteSession? prev, RemoteSession? next) {
    if (next == null || !next.isLive) {
      _stopHelp();
      if (prev != null && prev.isActive && mounted) {
        showResultSnack(context, context.l10n.kidRemoteEnded);
      }
      return;
    }
    if (next.isRequested && next.canAccept && _promptedFor != next.id) {
      _promptedFor = next.id;
      WidgetsBinding.instance.addPostFrameCallback((_) => _prompt(next));
    }
    if (next.isActive && next.isCall && _callOpenedFor != next.id) {
      _callOpenedFor = next.id;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openCall(next));
    }
    if (next.isActive && next.kind == 'in_app_help') {
      _startHelp(next);
    } else {
      _stopHelp();
    }
  }

  Future<void> _prompt(RemoteSession s) async {
    final l = context.l10n;
    final name = s.adultName ?? '';
    final title = s.isCall
        ? l.kidRemoteCallAsk(name)
        : l.kidRemoteHelpAsk(name);
    final body = s.kind == 'video_call'
        ? l.kidRemoteVideoBody
        : s.kind == 'voice_call'
        ? l.kidRemoteVoiceBody
        : l.kidRemoteHelpBody(name);
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null) return;
    final accept = await showModalBottomSheet<bool>(
      context: navContext,
      isDismissible: false,
      enableDrag: false,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                s.isCall
                    ? (s.isVideo ? Icons.videocam_rounded : Icons.call_rounded)
                    : Icons.support_agent_rounded,
                size: 56,
                color: sheet.mamily.brand.foreground,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: sheet.type.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                body,
                style: sheet.type.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: () => Navigator.of(sheet).pop(true),
                child: Text(s.isCall ? l.kidRemoteAnswer : l.kidRemoteAccept),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => Navigator.of(sheet).pop(false),
                child: Text(l.kidRemoteDecline),
              ),
            ],
          ),
        ),
      ),
    );
    final c = ref.read(kidRemoteProvider.notifier);
    if (accept == true) {
      try {
        await c.accept();
      } catch (e) {
        if (mounted) showKidError(context, e);
        await c.refresh();
      }
    } else {
      await c.decline();
    }
  }

  Future<void> _openCall(RemoteSession s) async {
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    await nav.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => CallScreen(
          repo: ref.read(kidRemoteRepositoryProvider),
          session: s,
          isOfferer: false,
          otherName: s.adultName ?? '',
        ),
      ),
    );
    await ref.read(kidRemoteProvider.notifier).refresh();
  }

  void _startHelp(RemoteSession s) {
    _frameTimer ??= Timer.periodic(
      const Duration(seconds: 2),
      (_) => _sendFrame(s.id),
    );
    _signalTimer ??= Timer.periodic(
      const Duration(milliseconds: 1500),
      (_) => _pollPointer(s.id),
    );
  }

  void _stopHelp() {
    _frameTimer?.cancel();
    _frameTimer = null;
    _signalTimer?.cancel();
    _signalTimer = null;
    _after = 0;
    if (_pointer != null && mounted) setState(() => _pointer = null);
  }

  /// Snapshot of the Mamily widget tree only (never other apps), scaled down.
  Future<void> _sendFrame(String id) async {
    if (!_foreground) return;
    final ro = _boundary.currentContext?.findRenderObject();
    if (ro is! RenderRepaintBoundary || ro.debugNeedsPaint) return;
    try {
      final width = ro.size.width;
      final image = await ro.toImage(pixelRatio: (360 / width).clamp(0.4, 1.0));
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) return;
      await ref
          .read(kidRemoteRepositoryProvider)
          .putFrame(id, base64Encode(bytes.buffer.asUint8List()));
    } catch (_) {}
  }

  Future<void> _pollPointer(String id) async {
    try {
      final r = await ref.read(kidRemoteRepositoryProvider).poll(id, _after);
      for (final s in r.signals) {
        _after = s.id;
        if (s.type == 'pointer') {
          final x = (s.payload['x'] as num?)?.toDouble();
          final y = (s.payload['y'] as num?)?.toDouble();
          if (x != null && y != null && mounted) {
            setState(() => _pointer = Offset(x.clamp(0, 1), y.clamp(0, 1)));
            Future<void>.delayed(const Duration(seconds: 4), () {
              if (mounted) setState(() => _pointer = null);
            });
          }
        }
      }
      if (!r.session.isActive) ref.read(kidRemoteProvider.notifier).refresh();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RemoteSession?>(kidRemoteProvider, _onSession);
    final s = ref.watch(kidRemoteProvider);
    final l = context.l10n;
    final c = context.mamily;
    final helping = s != null && s.isActive && s.kind == 'in_app_help';
    final waiting = s != null && s.isRequested && !s.canAccept;

    return Column(
      children: [
        if (helping || waiting)
          Material(
            color: helping ? c.danger.background : c.info.background,
            child: SafeArea(
              bottom: false,
              child: Semantics(
                liveRegion: true,
                container: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        helping
                            ? Icons.screen_share_rounded
                            : Icons.hourglass_top_rounded,
                        color: helping
                            ? c.danger.foreground
                            : c.info.foreground,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          helping
                              ? l.kidRemoteActive(s.adultName ?? '')
                              : l.kidRemoteWaitingFor(s.adultName ?? ''),
                          style: context.type.titleSmall,
                        ),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: helping ? c.danger.foreground : null,
                        ),
                        onPressed: () =>
                            ref.read(kidRemoteProvider.notifier).end(),
                        child: Text(helping ? l.kidRemoteStop : l.commonCancel),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: helping || waiting,
            child: Stack(
              children: [
                RepaintBoundary(key: _boundary, child: widget.child),
                if (_pointer != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: LayoutBuilder(
                        builder: (context, box) => Stack(
                          children: [
                            Positioned(
                              left: _pointer!.dx * box.maxWidth - 36,
                              top: _pointer!.dy * box.maxHeight - 36,
                              child: _PointerRing(label: l.kidRemoteLook),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PointerRing extends StatelessWidget {
  const _PointerRing({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.mamily;
    return Semantics(
      label: label,
      liveRegion: true,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: c.danger.foreground, width: 5),
          color: c.danger.foreground.withValues(alpha: 0.12),
        ),
      ),
    );
  }
}
