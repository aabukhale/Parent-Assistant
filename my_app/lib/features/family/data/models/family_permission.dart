/// The configurable family-member permission keys — mirrors the backend
/// `App\Enums\FamilyPermission` exactly (values verified against the enum, not
/// guessed).
///
/// Owner and parent implicitly hold **all** of these (backend
/// `FamilyAccess::effectivePermissions` returns the full set for them). A
/// caregiver holds only the keys an owner has granted, surfaced by
/// `FamilyMemberResource.effective_permissions`.
///
/// Child-*profile* management is deliberately **not** here — it stays role-gated
/// to owner/parent (Sprint 1 invariant). See [Permissions.canManageChildren].
enum FamilyPermission {
  manageTasks('manage_tasks'),
  approveTaskCompletions('approve_task_completions'),
  manageRewards('manage_rewards'),
  approveRedemptions('approve_redemptions'),
  reversePoints('reverse_points'),
  manageScreenTime('manage_screen_time'),
  grantExtraTime('grant_extra_time'),
  manageContentPolicy('manage_content_policy'),
  manageSleep('manage_sleep'),
  manageLearningGoals('manage_learning_goals'),
  manageActivities('manage_activities'),
  manageDevices('manage_devices'),
  viewReports('view_reports');

  const FamilyPermission(this.wire);

  /// The backend string value.
  final String wire;

  static FamilyPermission? fromWire(String? value) {
    for (final p in FamilyPermission.values) {
      if (p.wire == value) return p;
    }
    return null;
  }

  /// Parse a backend `effective_permissions` array, dropping any unknown keys.
  static Set<FamilyPermission> parseAll(Object? raw) {
    if (raw is! List) return const {};
    final result = <FamilyPermission>{};
    for (final entry in raw) {
      final p = fromWire(entry is String ? entry : entry?.toString());
      if (p != null) result.add(p);
    }
    return result;
  }

  static Set<FamilyPermission> get all => FamilyPermission.values.toSet();
}
