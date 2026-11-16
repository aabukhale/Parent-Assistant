import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/util/client_id.dart';
import '../../kid/presentation/kid_feedback.dart';
import '../../kid/presentation/kid_widgets.dart';
import '../application/kid_safety_providers.dart';
import '../application/location_reporter.dart';
import '../data/safety_models.dart';
import '../data/safety_repository.dart';

/// Opens the dialer. Never auto-dials: the child confirms in the phone app.
Future<void> callNumber(String number) async {
  final uri = Uri(
    scheme: 'tel',
    path: number.replaceAll(RegExp(r'[\s()-]'), ''),
  );
  try {
    await launchUrl(uri);
  } catch (_) {}
}

/// The child's help page: one large press-and-hold "I need help" button,
/// quick check-ins, and direct call buttons that work even offline.
class KidHelpScreen extends ConsumerStatefulWidget {
  const KidHelpScreen({super.key});

  @override
  ConsumerState<KidHelpScreen> createState() => _KidHelpScreenState();
}

enum _HelpPhase { idle, sending, sent, failed }

class _KidHelpScreenState extends ConsumerState<KidHelpScreen> {
  _HelpPhase _phase = _HelpPhase.idle;
  HelpAlert? _alert;

  /// One key per help attempt, reused for retries so a retry never creates a
  /// second alert.
  String? _clientId;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // Phone numbers may have changed since the cache was filled.
    Future.microtask(() => ref.invalidate(kidSafetyCentreProvider));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    HapticFeedback.heavyImpact();
    _clientId ??= newClientId();
    setState(() => _phase = _HelpPhase.sending);
    final fix = await LocationReporter.currentFix(
      timeout: const Duration(seconds: 6),
    );
    try {
      int? battery;
      try {
        battery = await Battery().batteryLevel;
      } catch (_) {}
      final alert = await ref
          .read(kidSafetyRepositoryProvider)
          .raiseHelp(clientId: _clientId!, at: fix, batteryPct: battery);
      if (!mounted) return;
      setState(() {
        _alert = alert;
        _phase = _HelpPhase.sent;
      });
      _startPolling();
    } catch (_) {
      if (mounted) setState(() => _phase = _HelpPhase.failed);
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) async {
      final id = _alert?.id;
      if (id == null) return;
      try {
        final a = await ref.read(kidSafetyRepositoryProvider).help(id);
        if (mounted) setState(() => _alert = a);
        if (!a.isOpen) _poll?.cancel();
      } catch (_) {}
    });
  }

  Future<void> _imOk() async {
    final id = _alert?.id;
    _poll?.cancel();
    if (id != null) {
      try {
        await ref.read(kidSafetyRepositoryProvider).cancelHelp(id);
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _phase = _HelpPhase.idle;
        _alert = null;
        _clientId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    final centre = ref.watch(kidSafetyCentreProvider).valueOrNull?.value;
    final showCalls =
        _phase == _HelpPhase.failed ||
        (_alert != null && _alert!.pushQueued == 0 && _alert!.isOpen);

    return Scaffold(
      appBar: AppBar(title: Text(l.kidHelpTitle)),
      body: AppContentFrame(
        maxWidth: 640,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (_phase == _HelpPhase.idle || _phase == _HelpPhase.sending)
              _HoldToSend(
                busy: _phase == _HelpPhase.sending,
                onConfirmed: _send,
              )
            else
              _HelpStatus(
                phase: _phase,
                alert: _alert,
                onRetry: _send,
                onOk: _imOk,
              ),
            if (_phase == _HelpPhase.idle) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l.kidHelpExplain,
                textAlign: TextAlign.center,
                style: context.type.bodyMedium?.copyWith(color: c.ink2),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            _CallSection(centre: centre, highlight: showCalls),
            const SizedBox(height: AppSpacing.xl),
            KidSectionTitle(l.kidQuickTitle),
            const QuickCheckins(),
          ],
        ),
      ),
    );
  }
}

/// A big red button that must be held for ~1.5 s. A tap alone does nothing
/// except show the hint, so it is hard to trigger by accident; screen readers
/// get a normal double-tap action with a confirmation.
class _HoldToSend extends StatefulWidget {
  const _HoldToSend({required this.busy, required this.onConfirmed});

  final bool busy;
  final VoidCallback onConfirmed;

  @override
  State<_HoldToSend> createState() => _HoldToSendState();
}

class _HoldToSendState extends State<_HoldToSend>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          widget.onConfirmed();
          _hold.reset();
        }
      });

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  Future<void> _semanticActivate() async {
    final l = context.l10n;
    final ok = await confirmAction(
      context,
      title: l.kidHelpButton,
      body: l.kidHelpExplain,
      confirmLabel: l.kidHelpButton,
    );
    if (ok) widget.onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    return Semantics(
      button: true,
      label: l.kidHelpButton,
      hint: l.kidHelpHold,
      onTap: widget.busy ? null : _semanticActivate,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: widget.busy ? null : (_) => _hold.forward(),
        onTapUp: (_) {
          if (_hold.status != AnimationStatus.completed) _hold.reverse();
        },
        onTapCancel: () => _hold.reverse(),
        child: AnimatedBuilder(
          animation: _hold,
          builder: (context, _) => Container(
            constraints: const BoxConstraints(minHeight: 180),
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: c.danger.background,
              borderRadius: AppRadii.xlAll,
              border: Border.all(color: c.danger.border, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: widget.busy ? null : _hold.value,
                          strokeWidth: 8,
                          color: c.danger.foreground,
                          backgroundColor: c.surface,
                        ),
                      ),
                      Icon(
                        Icons.sos_rounded,
                        size: 48,
                        color: c.danger.foreground,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  widget.busy ? l.kidHelpSending : l.kidHelpButton,
                  style: context.type.headlineSmall?.copyWith(
                    color: c.danger.foreground,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (!widget.busy)
                  Text(
                    l.kidHelpHold,
                    style: context.type.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HelpStatus extends StatelessWidget {
  const _HelpStatus({
    required this.phase,
    required this.alert,
    required this.onRetry,
    required this.onOk,
  });

  final _HelpPhase phase;
  final HelpAlert? alert;
  final VoidCallback onRetry;
  final VoidCallback onOk;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    final a = alert;

    if (phase == _HelpPhase.failed || a == null) {
      return KidCard(
        color: c.warning.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: c.warning.foreground),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(l.kidHelpFailed, style: context.type.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l.kidHelpTryAgain),
            ),
          ],
        ),
      );
    }

    final names = a.recipients.map((r) => r.name).join(', ');
    final seen = a.isAcknowledged;
    final (tone, icon, line) = seen
        ? (
            c.success,
            Icons.check_circle_rounded,
            l.kidHelpSeen(a.acknowledgedBy ?? ''),
          )
        : a.pushQueued == 0
        ? (c.warning, Icons.phone_in_talk_rounded, l.kidHelpNoPush)
        : (c.info, Icons.hourglass_top_rounded, l.kidHelpWaiting);

    return KidCard(
      color: tone.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 36, color: tone.foreground),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (names.isNotEmpty)
                        Text(
                          l.kidHelpSentTo(names),
                          style: context.type.titleMedium,
                        ),
                      Text(line, style: context.type.bodyLarge),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: onOk, child: Text(l.kidHelpImOk)),
        ],
      ),
    );
  }
}

class _CallSection extends StatelessWidget {
  const _CallSection({required this.centre, required this.highlight});

  final SafetyCentre? centre;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    final people =
        centre?.people.where((p) => p.phone != null).toList() ?? const [];
    final emergency = centre?.emergencyNumber;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KidSectionTitle(l.kidCallMyParent),
        if (people.isEmpty)
          Text(
            l.kidNoPhone,
            style: context.type.bodyLarge?.copyWith(color: c.ink2),
          ),
        for (final p in people) ...[
          SizedBox(
            height: 64,
            child: (highlight ? FilledButton.icon : OutlinedButton.icon)(
              onPressed: () => callNumber(p.phone!),
              icon: const Icon(Icons.call_rounded),
              label: Text(l.kidCallPerson(p.name)),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (emergency != null && emergency.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: c.danger.foreground,
                side: BorderSide(color: c.danger.border),
              ),
              onPressed: () => callNumber(emergency),
              icon: const Icon(Icons.emergency_rounded),
              label: Text(l.kidEmergencyCall(emergency)),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l.kidEmergencyNote,
            style: context.type.bodySmall?.copyWith(color: c.ink2),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Four big check-in buttons: "I arrived", "Pick me up", "Call me",
/// "I'm okay". Each is a separate, retry-safe message to the family.
class QuickCheckins extends ConsumerStatefulWidget {
  const QuickCheckins({super.key});

  @override
  ConsumerState<QuickCheckins> createState() => _QuickCheckinsState();
}

class _QuickCheckinsState extends ConsumerState<QuickCheckins> {
  String? _busy;
  final _keys = <String, String>{};

  Future<void> _send(String kind) async {
    final l = context.l10n;
    setState(() => _busy = kind);
    final key = _keys[kind] ??= newClientId();
    final sharing = ref.read(locationReporterProvider).sharing;
    final fix = sharing
        ? await LocationReporter.currentFix(timeout: const Duration(seconds: 6))
        : null;
    try {
      await ref
          .read(kidSafetyRepositoryProvider)
          .checkin(kind, clientId: key, at: fix);
      _keys.remove(kind);
      ref.invalidate(kidSafetyCheckinsProvider);
      if (kind == 'arrived') ref.invalidate(kidJourneyProvider);
      if (mounted) showResultSnack(context, l.kidCheckSent);
    } catch (e) {
      if (mounted) showKidError(context, e);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    final items = [
      ('arrived', l.kidCheckArrived, Icons.where_to_vote_rounded, c.success),
      ('okay', l.kidCheckOkay, Icons.thumb_up_alt_rounded, c.info),
      (
        'pick_me_up',
        l.kidCheckPickMeUp,
        Icons.directions_car_rounded,
        c.warning,
      ),
      ('call_me', l.kidCheckCallMe, Icons.phone_callback_rounded, c.warning),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 480 ? 4 : 2;
        final w = (box.maxWidth - AppSpacing.sm * (cols - 1)) / cols;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final (kind, label, icon, tone) in items)
              SizedBox(
                width: w,
                child: KidCard(
                  color: tone.background,
                  semanticLabel: label,
                  onTap: _busy == null ? () => _send(kind) : null,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.lg,
                    horizontal: AppSpacing.sm,
                  ),
                  child: Column(
                    children: [
                      _busy == kind
                          ? const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            )
                          : Icon(icon, size: 32, color: tone.foreground),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: context.type.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
