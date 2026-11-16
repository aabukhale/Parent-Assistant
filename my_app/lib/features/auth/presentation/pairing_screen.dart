import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/config/device_label.dart';
import '../../../core/design_system.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../application/auth_controller.dart';
import '../application/pairing_trace.dart';
import '../data/child_auth_repository.dart';

/// Waits between automatic retries when a pairing request can't reach the
/// server (about half a minute in all).
@visibleForTesting
List<Duration> pairingRetryDelays = const [
  Duration(seconds: 2),
  Duration(seconds: 3),
  Duration(seconds: 5),
  Duration(seconds: 8),
  Duration(seconds: 12),
];

/// Child joins the family: type the parent's code, scan their QR, or arrive
/// here from a `mamily://pair?code=…` link (prefilled).
class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({
    super.key,
    this.initialCode,
    this.autoSubmit = false,
    this.linkHadNoCode = false,
  });

  /// Opened from a `mamily://pair` link that carried no readable code: the
  /// screen says so instead of looking like nothing happened.
  final bool linkHadNoCode;

  final String? initialCode;

  /// Redeem [initialCode] right away. Used when the child scanned the
  /// parent's QR with the phone's camera (a `mamily://pair` link): that scan
  /// is the only step — no second scan, no extra tap.
  final bool autoSubmit;

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  late final _code = TextEditingController(text: widget.initialCode ?? '');
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.linkHadNoCode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _error = context.l10n.pairLinkNoCode);
      });
    }
    final code = widget.initialCode;
    if (widget.autoSubmit &&
        code != null &&
        normalizePairingCode(code) != null) {
      _busy = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pair();
      });
    }
  }

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
    // A connection failure (no signal yet, or iOS holding the very first
    // local-network request behind its permission prompt) is retried here
    // with the same code, so the child never has to scan again.
    for (var attempt = 0; ; attempt++) {
      PairingTrace.log(
        'redeem ${PairingTrace.mask(normalized)}, attempt ${attempt + 1}',
      );
      try {
        await ref
            .read(authControllerProvider.notifier)
            .pairChild(normalized, deviceName: childDeviceLabel());
        PairingTrace.log('paired, opening child home');
        if (!mounted) return;
        setState(() => _busy = false);
        Navigator.of(context).popUntil((r) => r.isFirst);
        return;
      } on ApiException catch (e) {
        PairingTrace.log('redeem failed: ${e.kind.name} ${e.statusCode ?? ''}');
        if (!mounted) return;
        final offline =
            e.kind == ApiErrorKind.network || e.kind == ApiErrorKind.timeout;
        if (offline && attempt < pairingRetryDelays.length) {
          setState(() => _error = l.pairRetrying);
          await Future<void>.delayed(pairingRetryDelays[attempt]);
          if (!mounted) return;
          continue;
        }
        setState(() {
          _busy = false;
          _error = switch (e.kind) {
            ApiErrorKind.validation => l.pairInvalid,
            ApiErrorKind.rateLimited => l.pairTooMany,
            _ when offline => l.pairNetworkFailed,
            _ => e.localizedMessage(l),
          };
        });
        return;
      }
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
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Flexible(child: Text(l.pairJoining)),
                            ],
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
