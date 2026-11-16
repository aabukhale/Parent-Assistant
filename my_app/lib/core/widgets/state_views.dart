import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/api_exception.dart';
import '../localization/l10n.dart';
import '../theme/app_typography.dart';
import '../theme/design_tokens.dart';
import '../theme/mamily_colors.dart';

/// Full-area loading indicator.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    final c = context.mamily;
    return Center(
      child: Semantics(
        liveRegion: true,
        label: message ?? context.l10n.commonLoading,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3.5,
                color: c.action,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ExcludeSemantics(
              child: Text(
                message ?? context.l10n.commonLoading,
                style: context.type.bodyMedium?.copyWith(color: c.ink2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state (success, but no rows). Friendly and specific — say what
/// will appear here and, when possible, what to do next via [action].
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    this.message,
    this.icon,
    this.onRefresh,
    this.title,
    this.action,
  });
  final String? message;
  final IconData? icon;
  final Future<void> Function()? onRefresh;
  final String? title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.mamily;
    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: c.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(icon ?? Icons.inbox_rounded, size: 34, color: c.ink2),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: context.type.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(
              message ?? context.l10n.commonEmpty,
              textAlign: TextAlign.center,
              style: context.type.bodyMedium?.copyWith(color: c.ink2),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
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
    final c = context.mamily;
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
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: c.brand.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 34, color: c.brand.foreground),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                message,
                textAlign: TextAlign.center,
                style: context.type.bodyLarge?.copyWith(color: c.ink),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l.commonRetry),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Honest "not available yet" surface for backend-deferred features
/// (AI coach, AI activity generation, biometric login).
class ComingSoonView extends StatelessWidget {
  const ComingSoonView({super.key, this.title, this.body, this.icon});
  final String? title;
  final String? body;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: c.info.background,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? Icons.hourglass_empty_rounded,
                size: 38,
                color: c.info.foreground,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title ?? l.commonComingSoonTitle,
              textAlign: TextAlign.center,
              style: context.type.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body ?? l.commonComingSoonBody,
              textAlign: TextAlign.center,
              style: context.type.bodyMedium?.copyWith(color: c.ink2),
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
