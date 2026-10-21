import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../auth/application/auth_controller.dart';
import '../data/remote_repository.dart';
import 'call_screen.dart';

/// Parent: choose what kind of help to offer, with an honest one-line
/// description of what each one can and cannot do.
Future<void> showStartRemoteSheet(
  BuildContext context,
  WidgetRef ref, {
  required String childId,
  required String childName,
}) async {
  final l = context.l10n;
  final kind = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: [
          Text(l.remoteSectionTitle, style: sheet.type.titleLarge),
          const SizedBox(height: AppSpacing.md),
          for (final (k, icon, title, body) in [
            (
              'in_app_help',
              Icons.support_agent_rounded,
              l.remoteHelpInMamily,
              l.remoteHelpExplain(childName),
            ),
            (
              'video_call',
              Icons.videocam_rounded,
              l.remoteVideoCall,
              l.remoteCallExplain(childName),
            ),
            (
              'voice_call',
              Icons.call_rounded,
              l.remoteVoiceCall,
              l.remoteCallExplain(childName),
            ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                onTap: () => Navigator.of(sheet).pop(k),
                semanticLabel: '$title. $body',
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconBadge(icon: icon, tone: AppTone.brand),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: sheet.type.titleSmall),
                          Text(body, style: sheet.type.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
  if (kind == null || !context.mounted) return;
  try {
    final s = await ref
        .read(parentRemoteRepositoryProvider)
        .request(
          kind,
          childId: childId,
          familyId: ref.read(activeFamilyIdProvider),
        );
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ParentRemoteScreen(sessionId: s.id, childName: childName),
      ),
    );
  } on ApiException catch (e) {
    if (!context.mounted) return;
    showResultSnack(
      context,
      e.kind == ApiErrorKind.conflict &&
              (e.rawMessage ?? '').contains('signed in')
          ? l.remoteNoDevice(childName)
          : e.localizedMessage(l),
    );
  }
}

/// Follows one session: waiting → (call screen | Mamily screen viewer) →
/// ended, with the reason in plain words. Also used to answer a child's
/// request (deep link from the notification).
class ParentRemoteScreen extends ConsumerStatefulWidget {
  const ParentRemoteScreen({
    super.key,
    required this.sessionId,
    this.childName,
  });

  final String sessionId;
  final String? childName;

  @override
  ConsumerState<ParentRemoteScreen> createState() => _ParentRemoteScreenState();
}

class _ParentRemoteScreenState extends ConsumerState<ParentRemoteScreen> {
  RemoteSession? _s;
  Timer? _timer;
  Uint8List? _frame;
  DateTime? _frameAt;
  bool _callOpened = false;
  final _frameKey = GlobalKey();

  RemoteRepository get _repo => ref.read(parentRemoteRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    try {
      final s = _s;
      if (s != null && s.isActive && s.kind == 'in_app_help') {
        final f = await _repo.frame(widget.sessionId);
        if (!mounted) return;
        setState(() {
          _s = f.session;
          if (f.frame != null) {
            _frame = base64Decode(f.frame!);
            _frameAt = f.at;
          }
        });
      } else {
        final next = await _repo.show(widget.sessionId);
        if (!mounted) return;
        setState(() => _s = next);
      }
      final now = _s!;
      if (!now.isLive) _timer?.cancel();
      if (now.isActive && now.isCall && !_callOpened) {
        _callOpened = true;
        _timer?.cancel();
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => CallScreen(
              repo: _repo,
              session: now,
              isOfferer: true,
              otherName: now.childName ?? widget.childName ?? '',
            ),
          ),
        );
        if (mounted) Navigator.of(context).maybePop();
      }
    } catch (_) {}
  }

  /// Sends where the parent tapped, as a fraction of the picture, so the
  /// child's app can draw a ring at the same spot.
  Future<void> _point(TapUpDetails d) async {
    final size =
        (_frameKey.currentContext?.findRenderObject() as RenderBox?)?.size;
    if (size == null || size.isEmpty) return;
    final x = d.localPosition.dx / size.width;
    final y = d.localPosition.dy / size.height;
    try {
      await _repo.signal(widget.sessionId, 'pointer', {'x': x, 'y': y});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = _s;
    final name = s?.childName ?? widget.childName ?? '';
    final ended = s != null && !s.isLive;

    final String? message = s == null
        ? null
        : switch (s.status) {
            'requested' when s.canAccept => null,
            'requested' => l.remoteWaitingChild(name),
            'declined' => l.remoteDeclined(name),
            'expired' => l.remoteNoAnswer,
            'ended'
                when s.endReason == 'authorization_lost' ||
                    s.endReason == 'revoked' =>
              l.remoteEndedNotAllowed,
            'ended' => l.remoteEnded,
            _ => null,
          };

    return Scaffold(
      appBar: AppBar(
        title: Text(
          s?.kind == 'in_app_help'
              ? l.remoteHelpInMamily
              : (s?.isVideo ?? false)
              ? l.remoteVideoCall
              : l.remoteVoiceCall,
        ),
      ),
      body: SafeArea(
        child: s == null
            ? const LoadingView()
            : Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (s.isRequested && s.canAccept) ...[
                      Text(
                        s.isCall
                            ? l.remoteChildCalling(name)
                            : l.remoteChildAsksHelp(name),
                        style: context.type.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton(
                        onPressed: () async {
                          try {
                            final r = await _repo.accept(s.id);
                            if (mounted) setState(() => _s = r);
                            _timer ??= Timer.periodic(
                              const Duration(milliseconds: 1500),
                              (_) => _tick(),
                            );
                            _tick();
                          } on ApiException catch (e) {
                            if (context.mounted) {
                              showResultSnack(context, e.localizedMessage(l));
                            }
                          }
                        },
                        child: Text(l.remoteAccept),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          await _repo.decline(s.id).catchError((_) => s);
                          if (context.mounted) Navigator.of(context).maybePop();
                        },
                        child: Text(l.remoteDecline),
                      ),
                    ] else if (message != null) ...[
                      const Spacer(),
                      Icon(
                        ended
                            ? Icons.info_outline_rounded
                            : Icons.hourglass_top_rounded,
                        size: 56,
                        color: context.mamily.ink2,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          message,
                          style: context.type.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const Spacer(),
                      if (!ended)
                        OutlinedButton(
                          onPressed: () async {
                            await _repo.end(s.id).catchError((_) => s);
                            if (context.mounted) {
                              Navigator.of(context).maybePop();
                            }
                          },
                          child: Text(l.commonCancel),
                        )
                      else
                        FilledButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: Text(l.commonDone),
                        ),
                    ] else if (s.isActive && s.kind == 'in_app_help') ...[
                      Text(
                        l.remoteTapToPoint(name),
                        style: context.type.bodyMedium,
                      ),
                      if (_frameAt != null)
                        Text(
                          l.remoteFrameAge(
                            DateTime.now()
                                .difference(_frameAt!)
                                .inSeconds
                                .clamp(0, 999),
                          ),
                          style: context.type.bodySmall,
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      Expanded(
                        child: _frame == null
                            ? Center(child: Text(l.remoteNoFrame(name)))
                            : Center(
                                child: GestureDetector(
                                  key: _frameKey,
                                  onTapUp: _point,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: context.mamily.borderStrong,
                                      ),
                                      borderRadius: AppRadii.mediumAll,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: AppRadii.mediumAll,
                                      child: Image.memory(
                                        _frame!,
                                        gaplessPlayback: true,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: context.mamily.danger.foreground,
                        ),
                        onPressed: () async {
                          await _repo.end(s.id).catchError((_) => s);
                          if (context.mounted) Navigator.of(context).maybePop();
                        },
                        icon: const Icon(Icons.stop_circle_rounded),
                        label: Text(l.remoteEnd),
                      ),
                    ] else
                      const Expanded(child: LoadingView()),
                  ],
                ),
              ),
      ),
    );
  }
}
