import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/design_system.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../application/hub_providers.dart';
import '../data/hub_models.dart';
import '../data/hub_repository.dart';

/// Shows a fresh single-use pairing code + QR for a child, with a live
/// countdown. Creating a new code cancels the previous one server-side.
Future<void> showPairingSheet(
  BuildContext context, {
  required String childId,
  required String childName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PairingSheet(childId: childId, childName: childName),
  );
}

class _PairingSheet extends ConsumerStatefulWidget {
  const _PairingSheet({required this.childId, required this.childName});

  final String childId;
  final String childName;

  @override
  ConsumerState<_PairingSheet> createState() => _PairingSheetState();
}

class _PairingSheetState extends ConsumerState<_PairingSheet> {
  PairingCode? _code;
  Object? _error;
  bool _busy = false;
  String _mode = 'child_dedicated';
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _create();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    // Leaving the sheet without using the code cancels it (best effort).
    final code = _code;
    if (code != null && code.state == 'active') {
      ref
          .read(hubRepositoryProvider)
          .revokePairingCode(widget.childId, code.id)
          .catchError((_) {});
    }
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = await ref
          .read(hubRepositoryProvider)
          .createPairingCode(widget.childId, deviceMode: _mode);
      if (mounted) setState(() => _code = code);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    final code = _code;
    final remaining = code?.expiresAt?.difference(DateTime.now());
    final expired = remaining != null && remaining.isNegative;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.pairTitleParent(widget.childName),
              style: context.type.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.pairHowTo,
              style: context.type.bodyMedium?.copyWith(color: c.ink2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'child_dedicated',
                  label: Text(l.pairModeDedicated),
                ),
                ButtonSegment(
                  value: 'family_shared',
                  label: Text(l.pairModeShared),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: _busy
                  ? null
                  : (s) {
                      setState(() => _mode = s.first);
                      _create();
                    },
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_error != null)
              ErrorRetryView(error: _error!, onRetry: _create)
            else if (code == null || _busy)
              const SizedBox(height: 240, child: LoadingView())
            else if (expired) ...[
              NoticeBanner(tone: AppTone.warning, message: l.pairExpired),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: _create, child: Text(l.pairNewCode)),
            ] else ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadii.largeAll,
                    border: Border.all(color: c.border),
                  ),
                  child: QrImageView(
                    data: code.qrPayload ?? '',
                    size: 200,
                    semanticsLabel: l.pairScan,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF24304F),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF24304F),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SelectableText(
                code.code ?? '',
                textAlign: TextAlign.center,
                style: context.type.displaySmall?.copyWith(
                  letterSpacing: 4,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l.pairExpiresIn((remaining!.inSeconds / 60).ceil()),
                textAlign: TextAlign.center,
                style: context.type.bodyMedium?.copyWith(color: c.ink2),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(onPressed: _create, child: Text(l.pairNewCode)),
              TextButton(
                onPressed: () async {
                  try {
                    await ref
                        .read(hubRepositoryProvider)
                        .revokePairingCode(widget.childId, code.id);
                    ref.invalidate(childDevicesProvider(widget.childId));
                    if (context.mounted) Navigator.of(context).pop();
                  } on ApiException catch (e) {
                    if (context.mounted) {
                      showResultSnack(context, e.localizedMessage(l));
                    }
                  }
                },
                child: Text(l.pairRevoke),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
