/// Canned backend payloads mirroring the real `/api/v1` response shapes
/// (see mamily `docs/backend-implementation.md` §4). Used only in tests.
class Fixtures {
  const Fixtures._();

  static Map<String, dynamic> userJson({
    String id = 'user-1',
    String firstName = 'Moaz',
    String? lastName = 'Razem',
    String email = 'moaz@example.com',
    String language = 'ar',
    List<Map<String, dynamic>>? memberships,
  }) => {
    'id': id,
    'first_name': firstName,
    'last_name': lastName,
    'email': email,
    'phone': null,
    'preferred_language': language,
    'timezone': 'Asia/Jerusalem',
    'status': 'active',
    'memberships': memberships ?? [membershipJson()],
  };

  static Map<String, dynamic> membershipJson({
    String id = 'member-1',
    String role = 'owner',
    String familyId = 'family-1',
    String familyName = 'Razem Family',
  }) => {
    'id': id,
    'role': role,
    'status': 'active',
    'joined_at': '2026-01-01T00:00:00.000Z',
    'family': {
      'id': familyId,
      'name': familyName,
      'owner_id': 'user-1',
      'timezone': 'Asia/Jerusalem',
      'preferred_language': 'ar',
    },
  };

  static Map<String, dynamic> meEnvelope({
    List<Map<String, dynamic>>? memberships,
  }) => {
    'success': true,
    'message': 'Authenticated user retrieved successfully.',
    'data': userJson(memberships: memberships),
  };

  static Map<String, dynamic> loginEnvelope({String token = 'tok_abc123'}) => {
    'success': true,
    'message': 'Login successful.',
    'data': {
      'token': token,
      'token_type': 'Bearer',
      'user': userJson(memberships: const []),
    },
  };

  static Map<String, dynamic> registerEnvelope({String token = 'tok_new123'}) =>
      {
        'success': true,
        'message': 'Registration successful.',
        'data': {
          'token': token,
          'token_type': 'Bearer',
          'user': userJson(memberships: const []),
          'family': membershipJson()['family'],
        },
      };

  static Map<String, dynamic> validationError({
    String message = 'The given data was invalid.',
    Map<String, List<String>>? errors,
  }) => {
    'success': false,
    'message': message,
    'errors':
        errors ??
        {
          'email': ['The email has already been taken.'],
        },
  };

  static Map<String, dynamic> paginated(
    List<Map<String, dynamic>> items, {
    int currentPage = 1,
    int lastPage = 1,
    int perPage = 15,
    int? total,
  }) => {
    'success': true,
    'message': 'OK',
    'data': items,
    'meta': {
      'current_page': currentPage,
      'last_page': lastPage,
      'per_page': perPage,
      'total': total ?? items.length,
    },
  };

  static Map<String, dynamic> messageEnvelope(
    String message, {
    bool success = true,
  }) => {'success': success, 'message': message};

  // --- Phase 3: interests + children ---

  static Map<String, dynamic> interestJson({
    String id = 'int-animals',
    String name = 'الحيوانات',
    String slug = 'animals',
    int sortOrder = 1,
  }) => {
    'id': id,
    'name': name,
    'slug': slug,
    'icon': null,
    'color': '#FFCC00',
    'is_active': true,
    'sort_order': sortOrder,
  };

  static Map<String, dynamic> interestsEnvelope() => {
    'success': true,
    'message': 'Interests retrieved successfully.',
    'data': [
      interestJson(
        id: 'int-animals',
        name: 'الحيوانات',
        slug: 'animals',
        sortOrder: 1,
      ),
      interestJson(
        id: 'int-drawing',
        name: 'الرسم',
        slug: 'drawing',
        sortOrder: 2,
      ),
    ],
  };

  static Map<String, dynamic> childJson({
    String id = 'child-1',
    String familyId = 'family-1',
    String name = 'ليان',
    String birthDate = '2017-05-04',
    int age = 8,
    String status = 'active',
    String? gender = 'female',
    String? avatarColor = '#FFE4DF',
    List<Map<String, dynamic>>? interests,
  }) => {
    'id': id,
    'family_id': familyId,
    'name': name,
    'birth_date': birthDate,
    'age': age,
    'gender': gender,
    'avatar_color': avatarColor,
    'preferred_language': null,
    'content_age_override': null,
    'status': status,
    'interests': interests ?? [interestJson()],
    'created_at': '2026-01-01T00:00:00.000Z',
    'updated_at': '2026-01-01T00:00:00.000Z',
  };

  static Map<String, dynamic> childEnvelope({
    Map<String, dynamic>? child,
    String message = 'OK',
  }) => {'success': true, 'message': message, 'data': child ?? childJson()};

  static Map<String, dynamic> childrenPage(
    List<Map<String, dynamic>> children, {
    int currentPage = 1,
    int lastPage = 1,
    int perPage = 20,
    int? total,
  }) => paginated(
    children,
    currentPage: currentPage,
    lastPage: lastPage,
    perPage: perPage,
    total: total ?? children.length,
  );

  // --- Phase 4: learning goals ---

  static Map<String, dynamic> goalProgressJson({
    String id = 'prog-1',
    double value = 5,
    String? note,
    String recordedAt = '2026-02-01T09:00:00.000Z',
  }) => {
    'id': id,
    'value': value,
    'note': note,
    'recorded_by': 'user-1',
    'recorded_at': recordedAt,
    'created_at': recordedAt,
  };

  static Map<String, dynamic> goalJson({
    String id = 'goal-1',
    String childId = 'child-1',
    String title = 'Read 20 books',
    String? description,
    String metric = 'numeric',
    double? targetValue = 20,
    String? unit = 'book',
    double currentValue = 5,
    double? progressPercentage = 25.0,
    String startDate = '2026-01-01',
    String? targetDate = '2026-06-30',
    String status = 'active',
    String? achievedAt,
    List<Map<String, dynamic>>? progress,
  }) => {
    'id': id,
    'child_id': childId,
    'title': title,
    'description': description,
    'metric': metric,
    'target_value': targetValue,
    'unit': unit,
    'current_value': currentValue,
    'progress_percentage': progressPercentage,
    'start_date': startDate,
    'target_date': targetDate,
    'status': status,
    'achieved_at': achievedAt,
    'created_by': 'user-1',
    'progress': progress ?? [goalProgressJson()],
    'created_at': '2026-01-01T00:00:00.000Z',
    'updated_at': '2026-02-01T00:00:00.000Z',
  };

  static Map<String, dynamic> goalEnvelope({
    Map<String, dynamic>? goal,
    String message = 'OK',
    int? status,
  }) => {'success': true, 'message': message, 'data': goal ?? goalJson()};

  static Map<String, dynamic> goalsPage(
    List<Map<String, dynamic>> goals, {
    int currentPage = 1,
    int lastPage = 1,
    int? total,
  }) => paginated(
    goals,
    currentPage: currentPage,
    lastPage: lastPage,
    perPage: 20,
    total: total ?? goals.length,
  );

  // --- Permissions: family members ---

  /// All 13 backend FamilyPermission values (owner/parent get this set).
  static const allPermissions = <String>[
    'manage_tasks',
    'approve_task_completions',
    'manage_rewards',
    'approve_redemptions',
    'reverse_points',
    'manage_screen_time',
    'grant_extra_time',
    'manage_content_policy',
    'manage_sleep',
    'manage_learning_goals',
    'manage_activities',
    'manage_devices',
    'view_reports',
  ];

  static Map<String, dynamic> memberJson({
    String id = 'member-test',
    String userId = 'user-test',
    String familyId = 'family-1',
    String role = 'owner',
    String status = 'active',
    List<String>? effectivePermissions,
    String firstName = 'Test',
  }) => {
    'id': id,
    'family_id': familyId,
    'user_id': userId,
    'role': role,
    'status': status,
    'joined_at': '2026-01-01T00:00:00.000Z',
    'user': {
      'id': userId,
      'first_name': firstName,
      'last_name': 'User',
      'email': '$firstName@example.com',
      'phone': null,
    },
    'effective_permissions':
        effectivePermissions ??
        (role == 'owner' || role == 'parent'
            ? allPermissions
            : const <String>[]),
  };

  static Map<String, dynamic> membersEnvelope(
    List<Map<String, dynamic>> members, {
    int currentPage = 1,
    int lastPage = 1,
  }) => paginated(
    members,
    currentPage: currentPage,
    lastPage: lastPage,
    perPage: 50,
  );

  static Map<String, dynamic> recordProgressEnvelope({
    Map<String, dynamic>? progress,
    Map<String, dynamic>? goal,
  }) => {
    'success': true,
    'message': 'Progress recorded successfully.',
    'data': {
      'progress': progress ?? goalProgressJson(id: 'prog-new', value: 20),
      'goal':
          goal ??
          goalJson(
            currentValue: 20,
            progressPercentage: 100,
            status: 'achieved',
            achievedAt: '2026-02-05T10:00:00.000Z',
          ),
    },
  };

  // --- Phase 5: sleep ---

  static Map<String, dynamic> sleepLogJson({
    String id = 'sleep-1',
    String childId = 'child-1',
    // 21:30 UTC → 07:00 next-day UTC = 570 minutes (crosses midnight in UTC).
    String startedAt = '2026-09-06T21:30:00.000Z',
    String endedAt = '2026-09-07T07:00:00.000Z',
    int durationMinutes = 570,
    String source = 'manual',
  }) => {
    'id': id,
    'child_id': childId,
    'started_at': startedAt,
    'ended_at': endedAt,
    'duration_minutes': durationMinutes,
    'source': source,
    'recorded_by': 'user-test',
    'created_at': '2026-09-07T07:05:00.000Z',
    'updated_at': '2026-09-07T07:05:00.000Z',
  };

  static Map<String, dynamic> sleepLogEnvelope({
    Map<String, dynamic>? log,
    String message = 'OK',
  }) => {'success': true, 'message': message, 'data': log ?? sleepLogJson()};

  static Map<String, dynamic> sleepLogsPage(
    List<Map<String, dynamic>> logs, {
    int currentPage = 1,
    int lastPage = 1,
    int? total,
  }) => paginated(
    logs,
    currentPage: currentPage,
    lastPage: lastPage,
    perPage: 20,
    total: total ?? logs.length,
  );

  static Map<String, dynamic> sleepSummaryEnvelope({
    String period = 'weekly',
    String timezone = 'Asia/Jerusalem',
    int nightsLogged = 2,
    int totalSleepMinutes = 1140,
    int averageSleepMinutes = 570,
    bool? hasSufficientData,
    List<Map<String, dynamic>>? nights,
  }) => {
    'success': true,
    'message': 'Sleep summary generated successfully.',
    'data': {
      'period': period,
      'timezone': timezone,
      'period_start': '2026-09-01',
      'period_end': '2026-09-07',
      'nights_logged': nightsLogged,
      'total_sleep_minutes': totalSleepMinutes,
      'average_sleep_minutes': averageSleepMinutes,
      'has_sufficient_data': hasSufficientData ?? (nightsLogged > 0),
      'nights':
          nights ??
          [
            {'date': '2026-09-05', 'sleep_minutes': 540},
            {'date': '2026-09-06', 'sleep_minutes': 600},
          ],
    },
  };

  // --- Phase 6A: tasks, completions, points ---

  static Map<String, dynamic> taskJson({
    String id = 'task-1',
    String childId = 'child-1',
    String title = 'Tidy the room',
    String? description,
    int points = 10,
    String recurrenceType = 'daily',
    Map<String, dynamic>? recurrenceConfig,
    String? deadlineAt,
    String? category,
    String status = 'active',
    List<Map<String, dynamic>>? completions,
  }) => {
    'id': id,
    'child_id': childId,
    'title': title,
    'description': description,
    'points': points,
    'recurrence_type': recurrenceType,
    'recurrence_config': recurrenceConfig,
    'deadline_at': deadlineAt,
    'category': category,
    'icon_key': null,
    'reminder_config': null,
    'status': status,
    'created_by': 'user-test',
    'completions': ?completions,
    'created_at': '2026-09-01T00:00:00.000Z',
    'updated_at': '2026-09-01T00:00:00.000Z',
  };

  static Map<String, dynamic> taskEnvelope({
    Map<String, dynamic>? task,
    String message = 'OK',
  }) => {'success': true, 'message': message, 'data': task ?? taskJson()};

  static Map<String, dynamic> tasksPage(
    List<Map<String, dynamic>> tasks, {
    int currentPage = 1,
    int lastPage = 1,
    int? total,
  }) => paginated(
    tasks,
    currentPage: currentPage,
    lastPage: lastPage,
    perPage: 20,
    total: total ?? tasks.length,
  );

  static Map<String, dynamic> completionJson({
    String id = 'comp-1',
    String taskId = 'task-1',
    String childId = 'child-1',
    String occurrenceDate = '2026-09-07',
    String status = 'pending',
    int? pointsAwarded,
    String? reviewNote,
    String? reviewedAt,
    String? reversedAt,
    String? reversalNote,
  }) => {
    'id': id,
    'child_task_id': taskId,
    'child_id': childId,
    'occurrence_date': occurrenceDate,
    'status': status,
    'requested_by': 'user-test',
    'reviewed_by': reviewedAt == null ? null : 'user-test',
    'reviewed_at': reviewedAt,
    'review_note': reviewNote,
    'points_awarded': pointsAwarded,
    'award_transaction_id': pointsAwarded == null ? null : 'txn-award-1',
    'reversed_at': reversedAt,
    'reversed_by': reversedAt == null ? null : 'user-test',
    'reversal_note': reversalNote,
    'created_at': '2026-09-07T08:00:00.000Z',
    'updated_at': '2026-09-07T08:00:00.000Z',
  };

  static Map<String, dynamic> completionEnvelope({
    Map<String, dynamic>? completion,
    String message = 'OK',
  }) => {
    'success': true,
    'message': message,
    'data': completion ?? completionJson(),
  };

  static Map<String, dynamic> completionsPage(
    List<Map<String, dynamic>> completions, {
    int currentPage = 1,
    int lastPage = 1,
    int? total,
  }) => paginated(
    completions,
    currentPage: currentPage,
    lastPage: lastPage,
    perPage: 25,
    total: total ?? completions.length,
  );

  static Map<String, dynamic> pointsBalanceEnvelope({
    String childId = 'child-1',
    int balance = 0,
  }) => {
    'success': true,
    'message': 'OK',
    'data': {'child_id': childId, 'balance': balance},
  };

  static Map<String, dynamic> pointTxJson({
    String id = 'txn-1',
    String childId = 'child-1',
    int amount = 10,
    String type = 'task_award',
    String? sourceType = 'task_completion',
    String? reference = 'Task: Tidy the room',
  }) => {
    'id': id,
    'child_id': childId,
    'amount': amount,
    'type': type,
    'source_type': sourceType,
    'source_id': 'comp-1',
    'actor_id': 'user-test',
    'reference': reference,
    'created_at': '2026-09-07T09:00:00.000Z',
  };

  static Map<String, dynamic> pointTxPage(
    List<Map<String, dynamic>> txs, {
    int currentPage = 1,
    int lastPage = 1,
    int? total,
  }) => paginated(
    txs,
    currentPage: currentPage,
    lastPage: lastPage,
    perPage: 25,
    total: total ?? txs.length,
  );

  // --- Phase 6B: rewards, redemptions, screen-time overrides ---

  static Map<String, dynamic> rewardJson({
    String id = 'reward-1',
    String? familyId = 'family-1',
    String? scope,
    String title = 'Ice cream',
    String? description,
    String type = 'physical',
    int pointsCost = 50,
    Map<String, dynamic>? metadata,
    bool isActive = true,
  }) => {
    'id': id,
    'family_id': familyId,
    'scope': scope ?? (familyId == null ? 'global' : 'family'),
    'title': title,
    'description': description,
    'type': type,
    'points_cost': pointsCost,
    'metadata': metadata,
    'is_active': isActive,
    'created_at': '2026-09-01T00:00:00.000Z',
    'updated_at': '2026-09-01T00:00:00.000Z',
  };

  static Map<String, dynamic> rewardEnvelope({
    Map<String, dynamic>? reward,
    String message = 'OK',
  }) => {'success': true, 'message': message, 'data': reward ?? rewardJson()};

  static Map<String, dynamic> rewardsPage(
    List<Map<String, dynamic>> rewards, {
    int currentPage = 1,
    int lastPage = 1,
    int? total,
  }) => paginated(
    rewards,
    currentPage: currentPage,
    lastPage: lastPage,
    perPage: 25,
    total: total ?? rewards.length,
  );

  static Map<String, dynamic> screenTimeOverrideJson({
    String id = 'sto-1',
    String childId = 'child-1',
    int additionalMinutes = 45,
    String? expiresAt = '2026-09-08T20:00:00.000Z',
    String source = 'reward_redemption',
    String? revokedAt,
    String redemptionId = 'redemption-1',
  }) => {
    'id': id,
    'child_id': childId,
    'additional_minutes': additionalMinutes,
    'starts_at': '2026-09-07T20:00:00.000Z',
    'expires_at': expiresAt,
    'source': source,
    'reason': 'Reward redemption',
    'reward_redemption_id': redemptionId,
    'is_active': revokedAt == null,
    'revoked_at': revokedAt,
    'revoked_by': revokedAt == null ? null : 'user-test',
    'created_at': '2026-09-07T20:00:00.000Z',
  };

  static Map<String, dynamic> redemptionJson({
    String id = 'redemption-1',
    String rewardId = 'reward-1',
    String childId = 'child-1',
    String status = 'pending',
    String rewardTitle = 'Ice cream',
    String rewardType = 'physical',
    int pointsCost = 50,
    String? reviewNote,
    String? deductionTxnId,
    String? refundTxnId,
    Map<String, dynamic>? screenTimeOverride,
  }) => {
    'id': id,
    'reward_id': rewardId,
    'child_id': childId,
    'status': status,
    'reward_title': rewardTitle,
    'reward_type': rewardType,
    'points_cost': pointsCost,
    'requested_by': 'user-test',
    'reviewed_by': status == 'pending' ? null : 'user-test',
    'reviewed_at': status == 'pending' ? null : '2026-09-07T10:00:00.000Z',
    'review_note': reviewNote,
    'deduction_transaction_id': deductionTxnId,
    'refund_transaction_id': refundTxnId,
    'screen_time_override': ?screenTimeOverride,
    'created_at': '2026-09-07T09:00:00.000Z',
    'updated_at': '2026-09-07T09:00:00.000Z',
  };

  static Map<String, dynamic> redemptionEnvelope({
    Map<String, dynamic>? redemption,
    String message = 'OK',
  }) => {
    'success': true,
    'message': message,
    'data': redemption ?? redemptionJson(),
  };

  static Map<String, dynamic> redemptionsPage(
    List<Map<String, dynamic>> redemptions, {
    int currentPage = 1,
    int lastPage = 1,
    int? total,
  }) => paginated(
    redemptions,
    currentPage: currentPage,
    lastPage: lastPage,
    perPage: 25,
    total: total ?? redemptions.length,
  );

  // --- Phase 7: dashboards & development reports ---

  /// A per-child digest, as returned by `…/children/{child}/summary` and each
  /// entry of the parent dashboard's `children[]`. Pass `null` for
  /// [effectiveLimitMinutes] / [remainingMinutes] / [lastSleep] to mirror the
  /// "no rule configured" / "no sleep logged" cases.
  static Map<String, dynamic> childSummaryJson({
    String childId = 'child-1',
    String name = 'ليان',
    int? age = 8,
    int pointsBalance = 0,
    int usedMinutes = 0,
    int? effectiveLimitMinutes,
    int? remainingMinutes,
    Map<String, dynamic>? lastSleep,
    int activeTasks = 0,
    int pendingApproval = 0,
    int activeGoals = 0,
    int achievedGoals = 0,
  }) => {
    'child_id': childId,
    'name': name,
    'age': age,
    'points_balance': pointsBalance,
    'screen_time_today': {
      'used_minutes': usedMinutes,
      'effective_limit_minutes': effectiveLimitMinutes,
      'remaining_minutes': remainingMinutes,
    },
    'last_sleep': lastSleep,
    'tasks': {'active': activeTasks, 'pending_approval': pendingApproval},
    'learning_goals': {'active': activeGoals, 'achieved': achievedGoals},
  };

  static Map<String, dynamic> lastSleepJson({
    String startedAt = '2026-09-06T21:00:00.000Z',
    String endedAt = '2026-09-07T06:00:00.000Z',
    int durationMinutes = 540,
  }) => {
    'started_at': startedAt,
    'ended_at': endedAt,
    'duration_minutes': durationMinutes,
  };

  static Map<String, dynamic> childSummaryEnvelope({
    Map<String, dynamic>? summary,
    String message = 'OK',
  }) => {
    'success': true,
    'message': message,
    'data': summary ?? childSummaryJson(),
  };

  static Map<String, dynamic> parentDashboardJson({
    String familyId = 'family-1',
    List<Map<String, dynamic>>? children,
  }) {
    final kids = children ?? [childSummaryJson()];
    return {
      'family_id': familyId,
      'children_count': kids.length,
      'children': kids,
    };
  }

  static Map<String, dynamic> parentDashboardEnvelope({
    Map<String, dynamic>? dashboard,
    String message = 'OK',
  }) => {
    'success': true,
    'message': message,
    'data': dashboard ?? parentDashboardJson(),
  };

  /// A development report. Each `*Data` flag flips the matching section's
  /// `has_data`; `hasSufficientData` defaults to "any section has data".
  static Map<String, dynamic> developmentReportJson({
    String period = 'weekly',
    String periodStart = '2026-09-01',
    String periodEnd = '2026-09-07',
    String timezone = 'Asia/Jerusalem',
    bool screenTimeData = false,
    int screenTimeTotal = 0,
    int screenTimeDailyAverage = 0,
    int daysWithUsage = 0,
    bool sleepData = false,
    int sleepNights = 0,
    int sleepTotal = 0,
    int sleepAverage = 0,
    bool activitiesData = false,
    int activitiesCompleted = 0,
    int activitiesApproved = 0,
    bool gamesData = false,
    int gamesSessions = 0,
    int gamesDistinct = 0,
    int gamesPlayMinutes = 0,
    bool tasksData = false,
    int tasksApproved = 0,
    int tasksPoints = 0,
    bool pointsData = false,
    int pointsNet = 0,
    int pointsTransactions = 0,
    bool? hasSufficientData,
  }) {
    final anyData =
        screenTimeData ||
        sleepData ||
        activitiesData ||
        gamesData ||
        tasksData ||
        pointsData;
    return {
      'schema_version': 1,
      'period': period,
      'period_start': periodStart,
      'period_end': periodEnd,
      'timezone': timezone,
      'generated_at': '2026-09-08T00:00:00.000Z',
      'has_sufficient_data': hasSufficientData ?? anyData,
      'sections': {
        'screen_time': {
          'has_data': screenTimeData,
          'total_minutes': screenTimeTotal,
          'days_with_usage': daysWithUsage,
          'daily_average_minutes': screenTimeDailyAverage,
        },
        'sleep': {
          'has_data': sleepData,
          'nights_logged': sleepNights,
          'total_minutes': sleepTotal,
          'average_minutes': sleepAverage,
        },
        'activities': {
          'has_data': activitiesData,
          'completed': activitiesCompleted,
          'approved': activitiesApproved,
        },
        'games': {
          'has_data': gamesData,
          'sessions': gamesSessions,
          'distinct_games': gamesDistinct,
          'total_play_minutes': gamesPlayMinutes,
        },
        'tasks': {
          'has_data': tasksData,
          'approved_completions': tasksApproved,
          'points_from_tasks': tasksPoints,
        },
        'points': {
          'has_data': pointsData,
          'net_change': pointsNet,
          'transaction_count': pointsTransactions,
        },
      },
    };
  }

  static Map<String, dynamic> developmentReportEnvelope({
    Map<String, dynamic>? report,
    String message = 'OK',
  }) => {
    'success': true,
    'message': message,
    'data': report ?? developmentReportJson(),
  };

  // --- Phase 8: activities ---

  static Map<String, dynamic> activityJson({
    String id = 'activity-1',
    String? familyId,
    String source = 'global',
    String title = 'Build a story',
    String? description = 'A fun creative activity.',
    int? durationMinutes = 30,
    int? minAge = 4,
    int? maxAge = 9,
    List<String>? materials,
    List<String>? steps,
    bool isActive = true,
  }) => {
    'id': id,
    'family_id': familyId,
    'source': source,
    'title': title,
    'description': description,
    'duration_minutes': durationMinutes,
    'min_age': minAge,
    'max_age': maxAge,
    'materials': materials ?? const <String>[],
    'steps': steps ?? const <String>[],
    'interests': const <Map<String, dynamic>>[],
    'is_active': isActive,
    'created_at': '2026-09-01T00:00:00.000Z',
  };

  static Map<String, dynamic> activityEnvelope({
    Map<String, dynamic>? activity,
    String message = 'OK',
  }) => {
    'success': true,
    'message': message,
    'data': activity ?? activityJson(),
  };

  static Map<String, dynamic> activitiesPage(
    List<Map<String, dynamic>> activities, {
    int currentPage = 1,
    int lastPage = 1,
    int? total,
  }) => paginated(
    activities,
    currentPage: currentPage,
    lastPage: lastPage,
    perPage: 20,
    total: total ?? activities.length,
  );

  static Map<String, dynamic> activityCompletionJson({
    String id = 'acomp-1',
    String assignmentId = 'assign-1',
    String childId = 'child-1',
    String status = 'pending',
    int? pointsAwarded,
    String? reviewNote,
    String? reviewedAt,
    String? reversedAt,
  }) => {
    'id': id,
    'activity_assignment_id': assignmentId,
    'child_id': childId,
    'status': status,
    'completed_at': '2026-09-08T10:00:00.000Z',
    'requested_by': 'user-test',
    'reviewed_by': reviewedAt == null ? null : 'user-test',
    'reviewed_at': reviewedAt,
    'review_note': reviewNote,
    'points_awarded': pointsAwarded,
    'award_transaction_id': pointsAwarded == null ? null : 'txn-a-1',
    'reversed_at': reversedAt,
    'reversed_by': reversedAt == null ? null : 'user-test',
    'reversal_note': null,
    'created_at': '2026-09-08T10:00:00.000Z',
  };

  static Map<String, dynamic> activityCompletionEnvelope({
    Map<String, dynamic>? completion,
    String message = 'OK',
  }) => {
    'success': true,
    'message': message,
    'data': completion ?? activityCompletionJson(),
  };

  static Map<String, dynamic> activityAssignmentJson({
    String id = 'assign-1',
    String activityId = 'activity-1',
    String childId = 'child-1',
    int pointsReward = 0,
    bool? requiresApproval,
    String status = 'assigned',
    String? dueDate,
    Map<String, dynamic>? activity,
    List<Map<String, dynamic>>? completions,
  }) => {
    'id': id,
    'activity_id': activityId,
    'child_id': childId,
    'assigned_by': 'user-test',
    'points_reward': pointsReward,
    'requires_approval': requiresApproval ?? (pointsReward > 0),
    'status': status,
    'due_date': dueDate,
    'activity': activity ?? activityJson(id: activityId),
    'completions': completions ?? const <Map<String, dynamic>>[],
    'created_at': '2026-09-07T00:00:00.000Z',
  };

  static Map<String, dynamic> activityAssignmentEnvelope({
    Map<String, dynamic>? assignment,
    String message = 'OK',
  }) => {
    'success': true,
    'message': message,
    'data': assignment ?? activityAssignmentJson(),
  };

  static Map<String, dynamic> activityAssignmentsPage(
    List<Map<String, dynamic>> assignments, {
    int currentPage = 1,
    int lastPage = 1,
    int? total,
  }) => paginated(
    assignments,
    currentPage: currentPage,
    lastPage: lastPage,
    perPage: 15,
    total: total ?? assignments.length,
  );

  // --- Phase 9: parent library ---

  static Map<String, dynamic> articleCategoryJson({
    String id = 'cat-1',
    String key = 'behaviour',
    String name = 'Behaviour',
    int sortOrder = 1,
  }) => {'id': id, 'key': key, 'name': name, 'sort_order': sortOrder};

  static Map<String, dynamic> articleCategoriesEnvelope([
    List<Map<String, dynamic>>? categories,
  ]) => {
    'success': true,
    'message': 'OK',
    'data':
        categories ??
        [
          articleCategoryJson(
            key: 'behaviour',
            name: 'Behaviour',
            sortOrder: 1,
          ),
          articleCategoryJson(
            id: 'cat-2',
            key: 'sleep',
            name: 'Sleep',
            sortOrder: 2,
          ),
        ],
  };

  static Map<String, dynamic> articleJson({
    String id = 'art-1',
    String slug = 'calm-tantrums',
    String title = 'Handling tantrums calmly',
    String? excerpt = 'A short lead-in to the article body…',
    String? body,
    String? authorName = 'Dr. Sarah',
    String? authorType = 'specialist',
    int? minAge = 2,
    int? maxAge = 8,
    List<Map<String, dynamic>>? categories,
  }) => {
    'id': id,
    'slug': slug,
    'title': title,
    'excerpt': excerpt,
    'body': body,
    'author': {'name': authorName, 'type': authorType},
    'min_age': minAge,
    'max_age': maxAge,
    'published_at': '2026-08-01T00:00:00.000Z',
    'categories': categories ?? [articleCategoryJson()],
    'interests': const <Map<String, dynamic>>[],
  };

  static Map<String, dynamic> articleEnvelope({
    Map<String, dynamic>? article,
    String message = 'OK',
  }) => {
    'success': true,
    'message': message,
    'data': article ?? articleJson(body: 'The full localized article body.'),
  };

  static Map<String, dynamic> articlesPage(
    List<Map<String, dynamic>> articles, {
    int currentPage = 1,
    int lastPage = 1,
    int? total,
  }) => paginated(
    articles,
    currentPage: currentPage,
    lastPage: lastPage,
    perPage: 15,
    total: total ?? articles.length,
  );

  static Map<String, dynamic> recommendationsEnvelope(
    List<Map<String, dynamic>> articles,
  ) => {
    'success': true,
    'message': articles.isEmpty
        ? 'No recommendations available yet.'
        : 'Recommendations retrieved successfully.',
    'data': articles,
  };

  // --- Phase 10: content catalog + policy ---

  static Map<String, dynamic> contentItemJson({
    String id = 'ci-1',
    String type = 'video',
    String title = 'Counting song',
    String? description = 'A short counting song.',
    Map<String, dynamic>? provider,
    String? externalRef = 'yt:abc',
    int? minAge = 2,
    int? maxAge = 6,
    List<Map<String, dynamic>>? categories,
  }) => {
    'id': id,
    'type': type,
    'title': title,
    'description': description,
    'provider': provider ?? {'key': 'youtube', 'name': 'YouTube Kids'},
    'external_ref': externalRef,
    'min_age': minAge,
    'max_age': maxAge,
    'status': 'approved',
    'published_at': '2026-07-01T00:00:00.000Z',
    'categories':
        categories ??
        [
          {
            'id': 'cc-1',
            'key': 'learning',
            'name': 'Learning',
            'sort_order': 1,
          },
        ],
    'interests': const <Map<String, dynamic>>[],
  };

  static Map<String, dynamic> contentItemEnvelope({
    Map<String, dynamic>? item,
  }) => {'success': true, 'message': 'OK', 'data': item ?? contentItemJson()};

  static Map<String, dynamic> contentCatalogPage(
    List<Map<String, dynamic>> items, {
    int currentPage = 1,
    int lastPage = 1,
    int? total,
  }) => paginated(
    items,
    currentPage: currentPage,
    lastPage: lastPage,
    perPage: 20,
    total: total ?? items.length,
  );

  static Map<String, dynamic> contentRuleJson({
    String id = 'rule-1',
    String childId = 'child-1',
    String ruleType = 'external_channel',
    String decision = 'block',
    String? categoryId,
    String? itemId,
    String? providerKey = 'youtube',
    String? externalRef = 'UCabc',
    String? label = 'A channel',
  }) => {
    'id': id,
    'child_id': childId,
    'rule_type': ruleType,
    'decision': decision,
    'content_category_id': categoryId,
    'content_item_id': itemId,
    'provider_key': providerKey,
    'external_ref': externalRef,
    'label': label,
    'created_at': '2026-09-08T00:00:00.000Z',
  };

  static Map<String, dynamic> contentRuleEnvelope({
    Map<String, dynamic>? rule,
    String message = 'OK',
  }) => {
    'success': true,
    'message': message,
    'data': rule ?? contentRuleJson(),
  };

  static Map<String, dynamic> contentRulesPage(
    List<Map<String, dynamic>> rules, {
    int currentPage = 1,
    int lastPage = 1,
    int? total,
  }) => paginated(
    rules,
    currentPage: currentPage,
    lastPage: lastPage,
    perPage: 50,
    total: total ?? rules.length,
  );

  static Map<String, dynamic> contentPolicyEnvelope({
    String childId = 'child-1',
    int? childAge = 5,
    int? contentAge = 5,
    bool ageFilterEnabled = true,
    Map<String, String>? categoryDecisions,
    Map<String, String>? itemDecisions,
    List<Map<String, dynamic>>? externalChannels,
  }) => {
    'success': true,
    'message': 'OK',
    'data': {
      'child_id': childId,
      'child_age': childAge,
      'content_age': contentAge,
      'age_filter_enabled': ageFilterEnabled,
      'category_decisions': categoryDecisions ?? <String, String>{},
      'item_decisions': itemDecisions ?? <String, String>{},
      'external_channels': externalChannels ?? const <Map<String, dynamic>>[],
    },
  };

  // --- Phase 11: devices + screen time ---

  static Map<String, dynamic> deviceJson({
    String id = 'dev-1',
    String familyId = 'family-1',
    String? childId,
    String name = "Layan's tablet",
    String platform = 'android',
    String deviceMode = 'family_shared',
    bool hasPushToken = false,
    bool isActive = true,
  }) => {
    'id': id,
    'family_id': familyId,
    'user_id': 'user-test',
    'child_id': childId,
    'name': name,
    'platform': platform,
    'device_mode': deviceMode,
    'has_push_token': hasPushToken,
    'app_version': '1.0.0',
    'os_version': '14',
    'last_seen_at': '2026-09-08T09:00:00.000Z',
    'is_active': isActive,
    'created_at': '2026-09-01T00:00:00.000Z',
    'updated_at': '2026-09-08T09:00:00.000Z',
  };

  static Map<String, dynamic> deviceEnvelope({Map<String, dynamic>? device}) =>
      {'success': true, 'message': 'OK', 'data': device ?? deviceJson()};

  static Map<String, dynamic> devicesPage(
    List<Map<String, dynamic>> devices, {
    int currentPage = 1,
    int lastPage = 1,
    int? total,
  }) => paginated(
    devices,
    currentPage: currentPage,
    lastPage: lastPage,
    perPage: 15,
    total: total ?? devices.length,
  );

  static Map<String, dynamic> screenTimeRuleJson({
    String id = 'str-1',
    String childId = 'child-1',
    String scope = 'default',
    int? dayOfWeek,
    int dailyLimitMinutes = 120,
    int? sessionLimitMinutes,
    String? allowedStartTime,
    String? allowedEndTime,
    bool isEnabled = true,
  }) => {
    'id': id,
    'child_id': childId,
    'scope': scope,
    'day_of_week': dayOfWeek,
    'daily_limit_minutes': dailyLimitMinutes,
    'session_limit_minutes': sessionLimitMinutes,
    'allowed_start_time': allowedStartTime,
    'allowed_end_time': allowedEndTime,
    'is_enabled': isEnabled,
  };

  static Map<String, dynamic> screenTimeRulesEnvelope([
    List<Map<String, dynamic>>? rules,
  ]) => {
    'success': true,
    'message': 'OK',
    'data': rules ?? [screenTimeRuleJson()],
  };

  static Map<String, dynamic> screenTimeSummaryEnvelope({
    int usedMinutes = 0,
    int? baseLimitMinutes,
    int bonusMinutes = 0,
    int? effectiveLimitMinutes,
    int? remainingMinutes,
    String ruleSource = 'none',
    bool? hasSufficientData,
    List<Map<String, dynamic>>? perApp,
  }) => {
    'success': true,
    'message': 'OK',
    'data': {
      'date': '2026-09-08',
      'timezone': 'Asia/Jerusalem',
      'used_seconds': usedMinutes * 60,
      'used_minutes': usedMinutes,
      'base_limit_minutes': baseLimitMinutes,
      'bonus_minutes': bonusMinutes,
      'effective_limit_minutes': effectiveLimitMinutes,
      'remaining_minutes': remainingMinutes,
      'rule_source': ruleSource,
      'has_sufficient_data':
          hasSufficientData ?? (perApp != null && perApp.isNotEmpty),
      'per_app': perApp ?? const <Map<String, dynamic>>[],
    },
  };

  static Map<String, dynamic> screenTimePolicyEnvelope({
    bool shouldLock = false,
    String? lockReason,
    String enforcementScope = 'child_mode_only',
    int? remainingMinutes,
  }) => {
    'success': true,
    'message': 'OK',
    'data': {
      'child_id': 'child-1',
      'should_lock': shouldLock,
      'lock_reason': lockReason,
      'enforcement_scope': enforcementScope,
      'remaining_minutes': remainingMinutes,
      'effective_limit_minutes': null,
      'note': 'The API reports policy only. Native code must enforce it.',
    },
  };

  static Map<String, dynamic> stOverrideJson({
    String id = 'sto-1',
    int additionalMinutes = 30,
    String source = 'manual',
    String? reason = 'Homework done',
    String? revokedAt,
  }) => {
    'id': id,
    'child_id': 'child-1',
    'additional_minutes': additionalMinutes,
    'starts_at': '2026-09-08T15:00:00.000Z',
    'expires_at': '2026-09-08T20:00:00.000Z',
    'source': source,
    'reason': reason,
    'reward_redemption_id': source == 'reward_redemption'
        ? 'redemption-1'
        : null,
    'is_active': revokedAt == null,
    'revoked_at': revokedAt,
    'revoked_by': revokedAt == null ? null : 'user-test',
    'created_at': '2026-09-08T15:00:00.000Z',
  };

  static Map<String, dynamic> stOverrideEnvelope({
    Map<String, dynamic>? override,
  }) => {
    'success': true,
    'message': 'OK',
    'data': override ?? stOverrideJson(),
  };

  static Map<String, dynamic> stOverridesPage(
    List<Map<String, dynamic>> overrides, {
    int currentPage = 1,
    int lastPage = 1,
    int? total,
  }) => paginated(
    overrides,
    currentPage: currentPage,
    lastPage: lastPage,
    perPage: 25,
    total: total ?? overrides.length,
  );

  static Map<String, dynamic> usageIngestEnvelope({
    String batchId = 'batch-1',
    int inserted = 3,
    int skipped = 0,
    bool replayed = false,
  }) => {
    'success': true,
    'message': replayed
        ? 'Batch already ingested.'
        : 'Usage ingested successfully.',
    'data': {
      'batch_id': batchId,
      'inserted': inserted,
      'skipped': skipped,
      'replayed': replayed,
    },
  };

  // --- Phase 12: games ---

  static Map<String, dynamic> gameJson({
    String id = 'game-1',
    String slug = 'memory-cards',
    String title = 'Memory cards',
    String? description = 'Flip and match the pairs.',
    String gameType = 'memory',
    int? minAge = 3,
    int? maxAge = 8,
    bool isActive = true,
  }) => {
    'id': id,
    'slug': slug,
    'title': title,
    'description': description,
    'game_type': gameType,
    'config': {'pairs': 8},
    'min_age': minAge,
    'max_age': maxAge,
    'is_active': isActive,
  };

  static Map<String, dynamic> gameEnvelope({Map<String, dynamic>? game}) => {
    'success': true,
    'message': 'OK',
    'data': game ?? gameJson(),
  };

  static Map<String, dynamic> gamesPage(
    List<Map<String, dynamic>> games, {
    int currentPage = 1,
    int lastPage = 1,
    int? total,
  }) => paginated(
    games,
    currentPage: currentPage,
    lastPage: lastPage,
    perPage: 20,
    total: total ?? games.length,
  );

  static Map<String, dynamic> gameProgressJson2({
    String id = 'gp-1',
    String gameId = 'game-1',
    int? bestScore = 120,
    int totalAttempts = 4,
    int totalPlaySeconds = 900,
  }) => {
    'id': id,
    'child_id': 'child-1',
    'game_id': gameId,
    'best_score': bestScore,
    'total_attempts': totalAttempts,
    'total_play_seconds': totalPlaySeconds,
    'last_played_at': '2026-09-07T18:00:00.000Z',
  };

  static Map<String, dynamic> gameProgressEnvelope([
    List<Map<String, dynamic>>? rows,
  ]) => {
    'success': true,
    'message': 'OK',
    'data': rows ?? [gameProgressJson2()],
  };

  static Map<String, dynamic> gameSessionEnvelope({
    String id = 'gs-1',
    String gameId = 'game-1',
    String status = 'in_progress',
    int? score,
  }) => {
    'success': true,
    'message': 'OK',
    'data': {
      'id': id,
      'game_id': gameId,
      'child_id': 'child-1',
      'device_id': null,
      'status': status,
      'started_at': '2026-09-08T10:00:00.000Z',
      'ended_at': status == 'in_progress' ? null : '2026-09-08T10:10:00.000Z',
      'score': score,
      'progress': null,
      'created_at': '2026-09-08T10:00:00.000Z',
    },
  };
}
