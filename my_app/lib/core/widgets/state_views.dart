import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/api_exception.dart';
import '../localization/l10n.dart';

const _navy = Color(0xFF2E3B63);
const _coral = Color(0xFFFF624E);
const _muted = Color(0xFF8A94AA);

/// Full-area loading indicator.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: _coral),
          const SizedBox(height: 14),
          Text(
            message ?? context.l10n.commonLoading,
            style: const TextStyle(color: _muted),
          ),
        ],
      ),
    );
  }
}

/// Empty state (success, but no rows).
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, this.message, this.icon, this.onRefresh});
  final String? message;
  final IconData? icon;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.inbox_rounded,
              size: 56,
              color: _muted.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 14),
            Text(
              message ?? context.l10n.commonEmpty,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 15),
            ),
          ],
        ),
      ),
    );
    if (onRefresh == null) return content;
    return RefreshIndicator(
      onRefresh: onRefresh!,
      child: ListView(children: [const SizedBox(height: 120), content]),
    );
  }
}

/// Error + retry. Distinguishes offline / auth / conflict / generic via [error].
class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({super.key, required this.error, this.onRetry});

  final Object error;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final message = error is ApiException
        ? (error as ApiException).localizedMessage(l)
        : l.errorUnknown;
    final icon = error is ApiException
        ? switch ((error as ApiException).kind) {
            ApiErrorKind.network ||
            ApiErrorKind.timeout => Icons.wifi_off_rounded,
            ApiErrorKind.forbidden => Icons.lock_outline_rounded,
            ApiErrorKind.notFound => Icons.search_off_rounded,
            ApiErrorKind.unavailable => Icons.cloud_off_rounded,
            _ => Icons.error_outline_rounded,
          }
        : Icons.error_outline_rounded;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: _coral),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _navy, fontSize: 15, height: 1.5),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l.commonRetry),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _coral,
                  side: const BorderSide(color: _coral),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Honest "not available yet" surface for backend-deferred features
/// (AI coach, nutrition analysis, biometric login).
class ComingSoonView extends StatelessWidget {
  const ComingSoonView({super.key, this.title, this.body, this.icon});
  final String? title;
  final String? body;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.hourglass_empty_rounded,
              size: 60,
              color: _muted,
            ),
            const SizedBox(height: 16),
            Text(
              title ?? l.commonComingSoonTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _navy,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body ?? l.commonComingSoonBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders an [AsyncValue] with consistent loading / error / data handling and
/// a pull-to-refresh wrapper for the data case.
class AsyncDataView<T> extends StatelessWidget {
  const AsyncDataView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.loading,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Future<void> Function()? onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: true,
      data: data,
      loading: () => loading ?? const LoadingView(),
      error: (e, _) => ErrorRetryView(error: e, onRetry: onRetry),
    );
  }
}
