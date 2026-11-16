import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
import '../../family/application/permissions_controller.dart';
import '../../family/data/models/family_permission.dart';
import '../application/content_controller.dart';
import '../data/content_requests.dart';
import '../data/models/content_enums.dart';
import '../data/models/content_item.dart';
import 'content_catalog_screen.dart';

/// Per-child content policy. Replaces Anwar's local-only toggle screen. Every
/// control persists through the Laravel API; the effective policy shown is
/// server-computed. This is **stored parental policy**, not device enforcement —
/// the app cannot itself block apps or media (see the disclaimer + docs).
class ContentControlScreen extends ConsumerWidget {
  const ContentControlScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final policy = ref.watch(contentPolicyProvider);
    final rules = ref.watch(contentRulesControllerProvider);
    final canManage = ref
        .watch(permissionsProvider)
        .hasPermission(FamilyPermission.manageContentPolicy);

    return Scaffold(
      appBar: AppBar(title: Text(l.contentTitle)),
      body: AppContentFrame(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(contentPolicyProvider);
            await ref.read(contentRulesControllerProvider.notifier).refresh();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            children: [
              _EnforcementDisclaimer(),
              const SizedBox(height: AppSpacing.md),
              policy.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => ErrorRetryView(
                  error: e,
                  onRetry: () async => ref.invalidate(contentPolicyProvider),
                ),
                data: (p) => _AgeFilterTile(
                  enabled: p.ageFilterEnabled,
                  contentAge: p.contentAge,
                  canManage: canManage,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Text(l.contentRulesTitle, style: context.type.titleSmall),
                  const Spacer(),
                  if (canManage)
                    TextButton.icon(
                      onPressed: () => _addExternalChannel(context, ref),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l.contentAddChannel),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              rules.when(
                skipLoadingOnReload: true,
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => ErrorRetryView(
                  error: e,
                  onRetry: ref
                      .read(contentRulesControllerProvider.notifier)
                      .refresh,
                ),
                data: (state) => state.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          l.contentRulesEmpty,
                          style: context.type.bodyMedium?.copyWith(
                            color: context.mamily.ink2,
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (final rule in state.rules)
                            _RuleTile(
                              rule: rule,
                              canManage: canManage,
                              onDelete: () =>
                                  _deleteRule(context, ref, rule.id),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ContentCatalogScreen(),
                  ),
                ),
                icon: const Icon(Icons.grid_view_rounded),
                label: Text(l.contentBrowseCatalog),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteRule(
    BuildContext context,
    WidgetRef ref,
    String ruleId,
  ) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(contentRulesControllerProvider.notifier)
          .deleteRule(ruleId);
      messenger.showSnackBar(SnackBar(content: Text(l.contentRuleRemoved)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.localizedMessage(l))));
    }
  }

  Future<void> _addExternalChannel(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final result = await showModalBottomSheet<ContentRuleInput>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ChannelRuleSheet(),
    );
    if (result == null) return;
    try {
      await ref.read(contentRulesControllerProvider.notifier).saveRule(result);
      messenger.showSnackBar(SnackBar(content: Text(l.contentRuleSaved)));
    } on ApiException catch (e) {
      final msg = e.kind == ApiErrorKind.validation
          ? l.contentRuleInvalid
          : e.localizedMessage(l);
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}

class _EnforcementDisclaimer extends StatelessWidget {
  @override
  Widget build(BuildContext context) => NoticeBanner(
    tone: AppTone.warning,
    message: context.l10n.contentEnforcementNote,
  );
}

class _AgeFilterTile extends ConsumerWidget {
  const _AgeFilterTile({
    required this.enabled,
    required this.contentAge,
    required this.canManage,
  });

  final bool enabled;
  final int? contentAge;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return AppCard(
      padding: EdgeInsets.zero,
      child: SwitchListTile(
        value: enabled,
        onChanged: canManage
            ? (v) async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ref
                      .read(contentRulesControllerProvider.notifier)
                      .setAgeFilter(enabled: v);
                } on ApiException catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(e.localizedMessage(l))),
                  );
                }
              }
            : null,
        title: Text(l.contentAgeFilter),
        subtitle: Text(
          contentAge == null
              ? l.contentAgeFilterSub
              : l.contentAgeFilterSubAge(contentAge!),
        ),
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.rule,
    required this.canManage,
    required this.onDelete,
  });

  final ContentRule rule;
  final bool canManage;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final blocked = rule.decision == ContentDecision.block;
    final typeLabel = switch (rule.ruleType) {
      ContentRuleType.category => l.contentRuleCategory,
      ContentRuleType.contentItem => l.contentRuleItem,
      ContentRuleType.externalChannel => l.contentRuleExternalChannel,
      ContentRuleType.unknown => l.contentRuleUnknown,
    };
    final subtitle =
        rule.label ??
        rule.externalRef ??
        rule.contentCategoryId ??
        rule.contentItemId ??
        '';

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          IconBadge(
            icon: blocked ? Icons.block_rounded : Icons.check_circle_rounded,
            tone: blocked ? AppTone.danger : AppTone.success,
            size: 40,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$typeLabel · ${blocked ? l.contentDecisionBlock : l.contentDecisionAllow}',
                  style: context.type.labelLarge,
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.bodySmall?.copyWith(
                      color: context.mamily.ink2,
                    ),
                  ),
              ],
            ),
          ),
          if (canManage)
            IconButton(
              tooltip: l.commonDelete,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: context.mamily.ink2,
              ),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

class _ChannelRuleSheet extends StatefulWidget {
  const _ChannelRuleSheet();

  @override
  State<_ChannelRuleSheet> createState() => _ChannelRuleSheetState();
}

class _ChannelRuleSheetState extends State<_ChannelRuleSheet> {
  final _provider = TextEditingController();
  final _ref = TextEditingController();
  final _label = TextEditingController();
  ContentDecision _decision = ContentDecision.block;

  @override
  void dispose() {
    _provider.dispose();
    _ref.dispose();
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.contentAddChannel, style: context.type.titleSmall),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _provider,
            decoration: InputDecoration(
              labelText: l.contentFieldProvider,
              hintText: 'youtube',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _ref,
            decoration: InputDecoration(
              labelText: l.contentFieldExternalRef,
              hintText: 'UCabc123',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _label,
            decoration: InputDecoration(
              labelText: l.contentFieldLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<ContentDecision>(
            segments: [
              ButtonSegment(
                value: ContentDecision.block,
                label: Text(l.contentDecisionBlock),
              ),
              ButtonSegment(
                value: ContentDecision.allow,
                label: Text(l.contentDecisionAllow),
              ),
            ],
            selected: {_decision},
            onSelectionChanged: (s) => setState(() => _decision = s.first),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _submit, child: Text(l.commonSave)),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final provider = _provider.text.trim();
    final ref = _ref.text.trim();
    if (provider.isEmpty || ref.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.contentRuleInvalid)));
      return;
    }
    Navigator.of(context).pop(
      ContentRuleInput.externalChannel(
        decision: _decision,
        providerKey: provider,
        externalRef: ref,
        label: _label.text.trim().isEmpty ? null : _label.text.trim(),
      ),
    );
  }
}
