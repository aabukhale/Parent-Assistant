import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../../family/application/permissions_controller.dart';
import '../../family/data/models/family_permission.dart';
import '../application/content_controller.dart';
import '../data/content_requests.dart';
import '../data/models/content_enums.dart';
import '../data/models/content_item.dart';

/// Browse the read-only content catalog (`GET /content`). For a parent with
/// `manage_content_policy`, tapping an item lets them add an allow/block rule
/// for that item or its category — persisted via `POST …/content-rules`.
class ContentCatalogScreen extends ConsumerWidget {
  const ContentCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(contentCatalogControllerProvider);
    final controller = ref.read(contentCatalogControllerProvider.notifier);
    final policy = ref.watch(contentPolicyProvider).valueOrNull;
    final canManage = ref
        .watch(permissionsProvider)
        .hasPermission(FamilyPermission.manageContentPolicy);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l.contentCatalogTitle,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: async.when(
            skipLoadingOnReload: true,
            loading: () => const LoadingView(),
            error: (e, _) => ListView(
              children: [
                const SizedBox(height: 120),
                ErrorRetryView(error: e, onRetry: controller.refresh),
              ],
            ),
            data: (state) => state.isEmpty
                ? EmptyView(
                    icon: Icons.grid_view_rounded,
                    message: l.contentCatalogEmpty,
                    onRefresh: controller.refresh,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
                    children: [
                      for (final item in state.items)
                        _CatalogTile(
                          item: item,
                          decision: policy?.itemDecisions[item.id],
                          onTapRule: canManage
                              ? () => _rule(context, ref, item)
                              : null,
                        ),
                      if (state.hasMore)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: state.loadingMore
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.coral,
                                  ),
                                )
                              : OutlinedButton(
                                  onPressed: () => _loadMore(context, ref),
                                  child: Text(l.libraryLoadMore),
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
      await ref.read(contentCatalogControllerProvider.notifier).loadMore();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.localizedMessage(context.l10n))));
    }
  }

  Future<void> _rule(
    BuildContext context,
    WidgetRef ref,
    ContentItem item,
  ) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showModalBottomSheet<ContentRuleInput>(
      context: context,
      builder: (_) => _ItemRuleSheet(item: item),
    );
    if (choice == null) return;
    try {
      await ref.read(contentRulesControllerProvider.notifier).saveRule(choice);
      messenger.showSnackBar(SnackBar(content: Text(l.contentRuleSaved)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.localizedMessage(l))));
    }
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    required this.item,
    required this.decision,
    required this.onTapRule,
  });

  final ContentItem item;
  final ContentDecision? decision;
  final VoidCallback? onTapRule;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              if (decision == ContentDecision.block)
                Text(
                  l.contentDecisionBlock,
                  style: const TextStyle(
                    color: AppColors.coral,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else if (decision == ContentDecision.allow)
                Text(
                  l.contentDecisionAllow,
                  style: const TextStyle(
                    color: Color(0xFF57C77A),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (item.provider != null) item.provider!.name,
              for (final c in item.categories) c.name,
            ].join(' · '),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          if (onTapRule != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onTapRule,
                icon: const Icon(Icons.rule_rounded, size: 16),
                label: Text(l.contentSetRule),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemRuleSheet extends StatelessWidget {
  const _ItemRuleSheet({required this.item});
  final ContentItem item;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cat = item.categories.isEmpty ? null : item.categories.first;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            _row(
              context,
              l.contentRuleBlockItem,
              () => Navigator.of(context).pop(
                ContentRuleInput.item(
                  decision: ContentDecision.block,
                  itemId: item.id,
                  label: item.title,
                ),
              ),
            ),
            _row(
              context,
              l.contentRuleAllowItem,
              () => Navigator.of(context).pop(
                ContentRuleInput.item(
                  decision: ContentDecision.allow,
                  itemId: item.id,
                  label: item.title,
                ),
              ),
            ),
            if (cat != null) ...[
              const Divider(),
              _row(
                context,
                l.contentRuleBlockCategory(cat.name),
                () => Navigator.of(context).pop(
                  ContentRuleInput.category(
                    decision: ContentDecision.block,
                    categoryId: cat.id,
                    label: cat.name,
                  ),
                ),
              ),
              _row(
                context,
                l.contentRuleAllowCategory(cat.name),
                () => Navigator.of(context).pop(
                  ContentRuleInput.category(
                    decision: ContentDecision.allow,
                    categoryId: cat.id,
                    label: cat.name,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, VoidCallback onTap) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        onTap: onTap,
      );
}
