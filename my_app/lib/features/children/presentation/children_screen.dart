import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/primary_button.dart';
import '../../family/application/permissions_controller.dart';
import '../application/children_controller.dart';
import '../application/selected_child_controller.dart';
import '../data/models/child.dart';
import 'child_form_screen.dart';
import 'child_details_screen.dart';

/// Children tab — real, paginated `GET /families/{family}/children`.
class ChildrenScreen extends ConsumerWidget {
  const ChildrenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final state = ref.watch(childrenControllerProvider);
    // Child-profile management stays role-gated to owner/parent (Sprint 1
    // invariant), surfaced centrally via permissionsProvider.
    final canManage = ref.watch(permissionsProvider).canManageChildren;
    final controller = ref.read(childrenControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l.childrenTitle,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButton: canManage && (state.valueOrNull?.isEmpty == false)
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.coral,
              foregroundColor: Colors.white,
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.childrenAdd),
            )
          : null,
      body: SafeArea(
        child: state.when(
          skipLoadingOnReload: true,
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.coral),
          ),
          error: (e, _) => _ErrorState(error: e, onRetry: controller.refresh),
          data: (list) => list.isEmpty
              ? _EmptyState(
                  canManage: canManage,
                  onAdd: () => _openForm(context),
                  onRefresh: controller.refresh,
                )
              : _List(
                  list: list,
                  canManage: canManage,
                  onRefresh: controller.refresh,
                  onLoadMore: () => _loadMore(context, ref),
                  onTapChild: (child) {
                    ref.read(selectedChildIdProvider.notifier).select(child.id);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChildDetailsScreen(childId: child.id),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const ChildFormScreen()));

  Future<void> _loadMore(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(childrenControllerProvider.notifier).loadMore();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.localizedMessage(context.l10n))));
    }
  }
}

class _List extends ConsumerWidget {
  const _List({
    required this.list,
    required this.canManage,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onTapChild,
  });

  final ChildrenListState list;
  final bool canManage;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final void Function(Child) onTapChild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final selectedId = ref.watch(selectedChildIdProvider);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 100),
        children: [
          Text(
            l.childrenSubtitle,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
          ),
          const SizedBox(height: 16),
          _FilterBar(current: list.statusFilter),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l.childrenCountLabel(list.meta.total),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          for (final child in list.children)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ChildCard(
                child: child,
                selected: child.id == selectedId,
                onTap: () => onTapChild(child),
              ),
            ),
          if (list.hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: list.loadingMore
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.coral),
                    )
                  : OutlinedButton(
                      onPressed: onLoadMore,
                      child: Text(l.childrenLoadMore),
                    ),
            ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.current});
  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final options = {
      'active': l.childrenFilterActive,
      'archived': l.childrenFilterArchived,
      'all': l.childrenFilterAll,
    };
    return Wrap(
      spacing: 8,
      children: [
        for (final entry in options.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: current == entry.key,
            onSelected: (_) => ref
                .read(childrenControllerProvider.notifier)
                .setStatusFilter(entry.key),
            selectedColor: AppColors.navy,
            labelStyle: TextStyle(
              color: current == entry.key ? Colors.white : AppColors.navy,
              fontSize: 13,
            ),
          ),
      ],
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({
    required this.child,
    required this.selected,
    required this.onTap,
  });
  final Child child;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final accent = _avatarColor(child.avatarColor);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppColors.teal : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.face_rounded,
                size: 32,
                color: AppColors.coral,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          child.name,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (child.status == ChildStatus.archived) ...[
                        const SizedBox(width: 8),
                        _ArchivedBadge(label: l.childrenFilterArchived),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    l.childAgeYears(child.age),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  if (child.interests.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      child.interests.take(3).map((i) => i.name).join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF62AFAF),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Color(0xFF9AA3B5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchivedBadge extends StatelessWidget {
  const _ArchivedBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFFEDEFF5),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.canManage,
    required this.onAdd,
    required this.onRefresh,
  });
  final bool canManage;
  final VoidCallback onAdd;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        children: [
          const SizedBox(height: 120),
          const Icon(
            Icons.face_rounded,
            size: 64,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 14),
          Text(
            l.childrenEmpty,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
          ),
          const SizedBox(height: 20),
          if (canManage)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: PrimaryButton(
                text: l.childrenAdd,
                icon: Icons.add_rounded,
                onPressed: onAdd,
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final message = error is ApiException
        ? (error as ApiException).localizedMessage(l)
        : l.errorUnknown;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: AppColors.coral,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

Color _avatarColor(String? hex) {
  if (hex == null || hex.isEmpty) return const Color(0xFFFFE6E1);
  final cleaned = hex.replaceAll('#', '');
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return const Color(0xFFFFE6E1);
  return Color(cleaned.length <= 6 ? 0xFF000000 | value : value);
}
