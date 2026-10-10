import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../family/application/permissions_controller.dart';
import '../../family_hub/application/hub_providers.dart';
import '../../family_hub/data/hub_models.dart';
import '../../family_hub/presentation/child_hub_screen.dart';
import '../../family_hub/presentation/hub_widgets.dart';
import '../application/children_controller.dart';
import '../application/selected_child_controller.dart';
import '../data/models/child.dart';
import 'child_form_screen.dart';

/// Children tab — real, paginated `GET /families/{family}/children`, each card
/// opening that child's hub.
class ChildrenScreen extends ConsumerWidget {
  const ChildrenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final state = ref.watch(childrenControllerProvider);
    // Child-profile management stays role-gated to owner/parent.
    final canManage = ref.watch(permissionsProvider).canManageChildren;
    final controller = ref.read(childrenControllerProvider.notifier);

    return Scaffold(
      floatingActionButton: canManage && (state.valueOrNull?.isEmpty == false)
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.childrenAdd),
            )
          : null,
      body: SafeArea(
        child: AppContentFrame(
          maxWidth: 860,
          child: state.when(
            skipLoadingOnReload: true,
            loading: () => const LoadingView(),
            error: (e, _) =>
                ErrorRetryView(error: e, onRetry: controller.refresh),
            data: (list) => RefreshIndicator(
              onRefresh: controller.refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  100,
                ),
                children: [
                  PageTitle(
                    title: l.childrenTitle,
                    subtitle: l.childrenSubtitle,
                  ),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      for (final entry in {
                        'active': l.childrenFilterActive,
                        'archived': l.childrenFilterArchived,
                        'all': l.childrenFilterAll,
                      }.entries)
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: list.statusFilter == entry.key,
                          onSelected: (_) =>
                              controller.setStatusFilter(entry.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (list.isEmpty)
                    EmptyView(
                      emoji: '👶',
                      message: l.childrenEmpty,
                      action: canManage
                          ? FilledButton.icon(
                              onPressed: () => _openForm(context),
                              icon: const Icon(Icons.add_rounded),
                              label: Text(l.childrenAdd),
                            )
                          : null,
                    )
                  else ...[
                    Text(
                      l.childrenCountLabel(list.meta.total),
                      style: context.type.bodySmall?.copyWith(
                        color: context.mamily.ink2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    LayoutBuilder(
                      builder: (context, box) {
                        final columns = box.maxWidth >= 640 ? 2 : 1;
                        final w = columns == 1
                            ? box.maxWidth
                            : (box.maxWidth - AppSpacing.md) / 2;
                        return Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.md,
                          children: [
                            for (final child in list.children)
                              SizedBox(
                                width: w,
                                child: _ChildCard(
                                  child: child,
                                  onTap: () {
                                    ref
                                        .read(selectedChildIdProvider.notifier)
                                        .select(child.id);
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            ChildHubScreen(childId: child.id),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    if (list.hasMore)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.lg),
                        child: list.loadingMore
                            ? const Center(child: CircularProgressIndicator())
                            : OutlinedButton(
                                onPressed: () => _loadMore(context, ref),
                                child: Text(l.childrenLoadMore),
                              ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const ChildFormScreen()));

  Future<void> _loadMore(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(childrenControllerProvider.notifier).loadMore();
    } on ApiException catch (e) {
      if (context.mounted) {
        showResultSnack(context, e.localizedMessage(context.l10n));
      }
    }
  }
}

class _ChildCard extends ConsumerWidget {
  const _ChildCard({required this.child, required this.onTap});

  final Child child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.mamily;
    final archived = child.status == ChildStatus.archived;
    final PulseChild? pulse = ref
        .watch(pulseProvider)
        .valueOrNull
        ?.value
        .children
        .where((p) => p.childId == child.id)
        .firstOrNull;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          ChildAvatar(
            name: child.name,
            avatarKey: child.avatarKey,
            colorHex: child.avatarColor,
            seed: child.id,
            size: 60,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(child.name, style: context.type.titleMedium),
                    ),
                    if (archived) ...[
                      const SizedBox(width: AppSpacing.sm),
                      StatusPill(
                        label: l.childrenFilterArchived,
                        tone: AppTone.neutral,
                      ),
                    ],
                  ],
                ),
                Text(
                  l.childAgeYears(child.age),
                  style: context.type.bodyMedium?.copyWith(color: c.ink2),
                ),
                if (pulse != null && !archived) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (pulse.tasksTotal > 0)
                        StatusPill(
                          label: l.pulseTasks(
                            pulse.tasksDone,
                            pulse.tasksTotal,
                          ),
                          tone: AppTone.success,
                          icon: Icons.task_alt_rounded,
                        ),
                      if (pulse.pendingApprovals > 0)
                        StatusPill(
                          label: l.pulseToReview(pulse.pendingApprovals),
                          tone: AppTone.brand,
                        ),
                      FreshnessBadge(
                        state: pulse.deviceState,
                        lastContactAt: pulse.lastContactAt,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? Icons.chevron_left_rounded
                : Icons.chevron_right_rounded,
            color: c.ink3,
          ),
        ],
      ),
    );
  }
}
