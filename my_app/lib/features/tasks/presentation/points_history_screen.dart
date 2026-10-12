import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../application/points_controller.dart';
import '../data/models/point_transaction.dart';
import 'task_widgets.dart';

/// The immutable points ledger (`GET …/point-transactions`). Read-only —
/// history is never deleted or edited.
class PointsHistoryScreen extends ConsumerWidget {
  const PointsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(pointsTxControllerProvider);
    final notifier = ref.read(pointsTxControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l.tasksPointsHistory)),
      body: AppContentFrame(
        child: RefreshIndicator(
          onRefresh: notifier.refresh,
          child: async.when(
            skipLoadingOnReload: true,
            loading: () => const LoadingView(),
            error: (e, _) =>
                ErrorRetryView(error: e, onRetry: notifier.refresh),
            data: (state) => state.isEmpty
                ? EmptyView(
                    emoji: '🧾',
                    message: l.tasksHistoryEmpty,
                    onRefresh: notifier.refresh,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.xxxl,
                    ),
                    children: [
                      for (final tx in state.transactions) _TxRow(tx: tx),
                      if (state.hasMore)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: state.loadingMore
                              ? const Center(child: CircularProgressIndicator())
                              : OutlinedButton(
                                  onPressed: () => _loadMore(context, ref),
                                  child: Text(l.tasksLoadMore),
                                ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadMore(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(pointsTxControllerProvider.notifier).loadMore();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.localizedMessage(context.l10n))));
    }
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.tx});
  final PointTransaction tx;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final numberFmt = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final c = context.mamily;
    final sign = tx.isCredit ? '+' : '−';
    final tone = tx.isCredit ? c.success : c.danger;
    final details = [
      if ((tx.reference ?? '').isNotEmpty) tx.reference!,
      if (tx.createdAt != null) formatTaskDateTime(context, tx.createdAt!),
    ].join('\n');
    return AppListTile(
      leading: IconBadge(
        icon: tx.isCredit ? Icons.add_rounded : Icons.remove_rounded,
        tone: tx.isCredit ? AppTone.success : AppTone.danger,
        size: 40,
      ),
      title: txnTypeLabel(l, tx.type),
      subtitle: details,
      subtitleMaxLines: 3,
      trailing: Text(
        '$sign${numberFmt.format(tx.amount.abs())}',
        style: context.type.titleMedium?.copyWith(color: tone.foreground),
      ),
    );
  }
}
