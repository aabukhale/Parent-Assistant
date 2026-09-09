import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l.stExtraTime,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: ref.read(overridesControllerProvider.notifier).refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              if (canGrant) ...[
                Text(
                  l.stExtraHowMuch,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in [15, 30, 45, 60, 90])
                      ChoiceChip(
                        label: Text('$m'),
                        selected: _minutes == m,
                        onSelected: (_) => setState(() => _minutes = m),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reason,
                  decoration: InputDecoration(
                    labelText: l.stExtraReason,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _grant,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.coral,
                      foregroundColor: Colors.white,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(l.stExtraGrant),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Text(
                l.stExtraHistory,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              async.when(
                skipLoadingOnReload: true,
                loading: () => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.coral),
                  ),
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
                          style: const TextStyle(color: AppColors.textMuted),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            o.isRevoked ? Icons.timer_off_outlined : Icons.more_time_rounded,
            color: o.isRevoked ? AppColors.textMuted : const Color(0xFF57C77A),
            size: 20,
          ),
          const SizedBox(width: 10),
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
                  style: TextStyle(
                    color: o.isRevoked ? AppColors.textMuted : AppColors.navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  o.isFromReward ? l.stExtraFromReward : l.stExtraFromParent,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                if ((o.reason ?? '').isNotEmpty)
                  Text(
                    o.reason!,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
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
