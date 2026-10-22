import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/config/device_label.dart';
import '../../../core/design_system.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../application/auth_controller.dart';
import '../data/child_auth_repository.dart';

/// Child joins the family: type the parent's code, scan their QR, or arrive
/// here from a `mamily://pair?code=…` link (prefilled).
class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  late final _code = TextEditingController(text: widget.initialCode ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _pair([String? scanned]) async {
    final l = context.l10n;
    final raw = scanned ?? _code.text;
    final normalized = pairingCodeFromLink(raw);
    if (normalized == null) {
      setState(() => _error = l.pairInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .pairChild(normalized, deviceName: childDeviceLabel());
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = switch (e.kind) {
          ApiErrorKind.validation => l.pairInvalid,
          ApiErrorKind.rateLimited => l.pairTooMany,
          _ => e.localizedMessage(l),
        };
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final result = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const _QrScanScreen()));
    if (result != null && mounted) {
      _code.text = pairingCodeFromLink(result) ?? '';
      await _pair(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    return Theme(
      data: AppTheme.kid,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(),
          body: AppContentFrame(
            child: AppContentFrame(
              maxWidth: 520,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                children: [
                  Center(
                    child: ExcludeSemantics(
                      child: Icon(
                        Icons.group_add_rounded,
                        size: 64,
                        color: context.mamily.brand.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    header: true,
                    child: Text(
                      l.pairTitle,
                      textAlign: TextAlign.center,
                      style: context.type.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l.pairSubtitle,
                    textAlign: TextAlign.center,
                    style: context.type.bodyLarge?.copyWith(color: c.ink2),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  TextField(
                    controller: _code,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLength: 9,
                    style: context.type.headlineSmall?.copyWith(
                      letterSpacing: 0,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9\- ]'),
                      ),
                    ],
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _pair(),
                    decoration: InputDecoration(
                      labelText: l.pairCodeLabel,
                      hintText: l.pairCodeHint,
                      counterText: '',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    NoticeBanner(tone: AppTone.danger, message: _error!),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: _busy ? null : () => _pair(),
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(l.pairButton),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _scan,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: Text(l.pairScan),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QrScanScreen extends StatefulWidget {
  const _QrScanScreen();

  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.pairScan)),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: NoticeBanner(
                  tone: AppTone.warning,
                  message: l.pairCameraDenied,
                ),
              ),
            ),
            onDetect: (capture) {
              if (_done) return;
              for (final b in capture.barcodes) {
                final raw = b.rawValue;
                if (raw != null && pairingCodeFromLink(raw) != null) {
                  _done = true;
                  Navigator.of(context).pop(raw);
                  return;
                }
              }
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(AppSpacing.xl),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: AppRadii.largeAll,
                ),
                child: Text(
                  l.pairScanInstruction,
                  textAlign: TextAlign.center,
                  style: context.type.bodyLarge?.copyWith(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
