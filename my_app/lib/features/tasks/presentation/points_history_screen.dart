import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l.tasksPointsHistory,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: notifier.refresh,
          child: async.when(
            skipLoadingOnReload: true,
            loading: () => const LoadingView(),
            error: (e, _) =>
                ErrorRetryView(error: e, onRetry: notifier.refresh),
            data: (state) => state.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Text(
                          l.tasksHistoryEmpty,
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                      for (final tx in state.transactions) _TxRow(tx: tx),
                      if (state.hasMore)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: state.loadingMore
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.coral,
                                  ),
                                )
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
    final sign = tx.isCredit ? '+' : '−';
    final color = tx.isCredit ? const Color(0xFF57C77A) : AppColors.coral;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txnTypeLabel(l, tx.type),
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if ((tx.reference ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    tx.reference!,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (tx.createdAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    formatTaskDateTime(context, tx.createdAt!),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '$sign${numberFmt.format(tx.amount.abs())}',
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
