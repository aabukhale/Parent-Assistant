import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
import '../../dashboard/presentation/dashboard_widgets.dart';
import '../../family/application/permissions_controller.dart';
import '../../family/data/models/family_permission.dart';
import '../application/screen_time_controller.dart';
import '../data/models/screen_time_models.dart';
import '../data/screen_time_repository.dart';

/// Grant / revoke manual extra screen time (`…/screen-time-overrides`). Grants
/// persist through the API; the effective limit is recomputed server-side.
class ExtraTimeScreen extends ConsumerStatefulWidget {
  const ExtraTimeScreen({super.key});

  @override
  ConsumerState<ExtraTimeScreen> createState() => _ExtraTimeScreenState();
}

class _ExtraTimeScreenState extends ConsumerState<ExtraTimeScreen> {
  int _minutes = 30;
  final _reason = TextEditingController();
  bool _submitting = false;
  final Set<String> _revoking = {};

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final canGrant = ref
        .watch(permissionsProvider)
        .hasPermission(FamilyPermission.grantExtraTime);
    final async = ref.watch(overridesControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.stExtraTime)),
      body: AppContentFrame(
        child: RefreshIndicator(
          onRefresh: ref.read(overridesControllerProvider.notifier).refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            children: [
              if (canGrant) ...[
                Text(l.stExtraHowMuch, style: context.type.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                ChoiceChipBar<int>(
                  options: {
                    for (final m in [15, 30, 45, 60, 90])
                      m: formatDurationMinutes(context, m),
                  },
                  selected: _minutes,
                  onSelected: (m) => setState(() => _minutes = m),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _reason,
                  decoration: InputDecoration(labelText: l.stExtraReason),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : _grant,
                    child: _submitting
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.mamily.onAction,
                            ),
                          )
                        : Text(l.stExtraGrant),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
              SectionHeader(title: l.stExtraHistory),
              async.when(
                skipLoadingOnReload: true,
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => ErrorRetryView(
                  error: e,
                  onRetry: ref
                      .read(overridesControllerProvider.notifier)
                      .refresh,
                ),
                data: (state) => state.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          l.stExtraHistoryEmpty,
                          style: context.type.bodyMedium?.copyWith(
                            color: context.mamily.ink2,
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (final o in state.overrides)
                            _OverrideTile(
                              data: o,
                              canRevoke: canGrant && !o.isRevoked,
                              revoking: _revoking.contains(o.id),
                              onRevoke: () => _revoke(o.id),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _grant() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    try {
      await ref
          .read(overridesControllerProvider.notifier)
          .grant(
            GrantExtraTimeInput(
              additionalMinutes: _minutes,
              reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
            ),
          );
      _reason.clear();
      messenger.showSnackBar(SnackBar(content: Text(l.stExtraGranted)));
    } on ApiException catch (e) {
      final msg = e.kind == ApiErrorKind.validation
          ? l.stExtraInvalid
          : e.localizedMessage(l);
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _revoke(String id) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _revoking.add(id));
    try {
      await ref.read(overridesControllerProvider.notifier).revoke(id);
      messenger.showSnackBar(SnackBar(content: Text(l.stExtraRevoked)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.localizedMessage(l))));
    } finally {
      if (mounted) setState(() => _revoking.remove(id));
    }
  }
}

class _OverrideTile extends StatelessWidget {
  const _OverrideTile({
    required this.data,
    required this.canRevoke,
    required this.revoking,
    required this.onRevoke,
  });

  final ScreenTimeOverride data;
  final bool canRevoke;
  final bool revoking;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final o = data;
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          IconBadge(
            icon: o.isRevoked
                ? Icons.timer_off_outlined
                : Icons.more_time_rounded,
            tone: o.isRevoked ? AppTone.neutral : AppTone.success,
            size: 40,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.isRevoked
                      ? l.stExtraRevokedLabel
                      : l.stExtraGrantedLabel(
                          formatDurationMinutes(context, o.additionalMinutes),
                        ),
                  style: context.type.labelLarge?.copyWith(
                    color: o.isRevoked
                        ? context.mamily.ink2
                        : context.mamily.ink,
                  ),
                ),
                Text(
                  o.isFromReward ? l.stExtraFromReward : l.stExtraFromParent,
                  style: context.type.bodySmall?.copyWith(
                    color: context.mamily.ink2,
                  ),
                ),
                if ((o.reason ?? '').isNotEmpty)
                  Text(
                    o.reason!,
                    style: context.type.bodySmall?.copyWith(
                      color: context.mamily.ink2,
                    ),
                  ),
              ],
            ),
          ),
          if (revoking)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (canRevoke)
            TextButton(onPressed: onRevoke, child: Text(l.stExtraRevokeAction)),
        ],
      ),
    );
  }
}
