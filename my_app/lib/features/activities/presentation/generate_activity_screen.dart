import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../children/application/selected_child_controller.dart';
import '../../family/application/permissions_controller.dart';
import '../../family/data/models/family_permission.dart';
import '../data/activities_repository.dart';
import '../data/activity_requests.dart';

/// AI activity generation. The Mamily backend ships an `UnavailableActivityGenerator`
/// that responds **503** until `AI_ACTIVITY_PROVIDER` + credentials are
/// configured — no activity is ever fabricated or persisted. This screen is an
/// honest "not available yet" state; the "Check again" button really calls
/// `POST …/activities/generate` so it lights up automatically once a provider
/// exists.
class GenerateActivityScreen extends ConsumerStatefulWidget {
  const GenerateActivityScreen({super.key});

  @override
  ConsumerState<GenerateActivityScreen> createState() =>
      _GenerateActivityScreenState();
}

class _GenerateActivityScreenState
    extends ConsumerState<GenerateActivityScreen> {
  bool _checking = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scope = ref.watch(childScopeProvider);
    final canManage = ref
        .watch(permissionsProvider)
        .hasPermission(FamilyPermission.manageActivities);
    final canTry = scope.familyId != null && scope.childId != null && canManage;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l.activityGenerateTitle,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 60,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  l.activityGenerateUnavailableTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l.activityGenerateUnavailableBody,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.coral,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                if (canTry)
                  OutlinedButton.icon(
                    onPressed: _checking ? null : _check,
                    icon: _checking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(l.activityGenerateCheckAgain),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _check() async {
    final scope = ref.read(childScopeProvider);
    if (scope.familyId == null || scope.childId == null) return;
    setState(() {
      _checking = true;
      _message = null;
    });
    final l = context.l10n;
    try {
      final generated = await ref
          .read(activitiesRepositoryProvider)
          .generate(
            scope.familyId!,
            scope.childId!,
            const GenerateActivityInput(),
          );
      if (!mounted) return;
      setState(() {
        _message = generated.isEmpty
            ? l.activityGenerateEmpty
            : l.activityGenerateNowAvailable(generated.length);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.kind == ApiErrorKind.unavailable
            ? l.activityGenerateStill503
            : e.localizedMessage(l);
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }
}
