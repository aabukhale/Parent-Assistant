import 'package:flutter/material.dart';

import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';

/// Plain-language state of one phone, for parents. Never says "on" unless the
/// phone itself confirmed it recently.
({String title, String body, AppTone tone, IconData icon}) deviceStateText(
  AppLocalizations l,
  String state, {
  required String childName,
  String? when,
}) => switch (state) {
  'active' => (
    title: l.rulesStateActive,
    body: l.rulesStateActiveBody(when ?? ''),
    tone: AppTone.success,
    icon: Icons.verified_rounded,
  ),
  'partially_active' => (
    title: l.rulesStatePartial,
    body: l.rulesStatePartialBody,
    tone: AppTone.warning,
    icon: Icons.rule_rounded,
  ),
  'waiting_for_device' => (
    title: l.rulesStateWaiting,
    body: l.rulesStateWaitingBody,
    tone: AppTone.info,
    icon: Icons.hourglass_top_rounded,
  ),
  'device_offline' => (
    title: l.rulesStateOffline,
    body: l.rulesStateOfflineBody(when ?? '—'),
    tone: AppTone.neutral,
    icon: Icons.cloud_off_rounded,
  ),
  'permission_needed' => (
    title: l.rulesStatePermission,
    body: l.rulesStatePermissionBody(childName),
    tone: AppTone.warning,
    icon: Icons.lock_open_rounded,
  ),
  'unsupported' => (
    title: l.rulesStateUnsupported,
    body: l.rulesStateUnsupportedBody(childName),
    tone: AppTone.neutral,
    icon: Icons.block_rounded,
  ),
  'no_rules' => (
    title: l.rulesStateNoRules,
    body: l.rulesStateNoRulesBody,
    tone: AppTone.neutral,
    icon: Icons.tune_rounded,
  ),
  'no_device' => (
    title: l.rulesNoDevice,
    body: l.rulesNoDeviceBody(childName),
    tone: AppTone.neutral,
    icon: Icons.phonelink_off_rounded,
  ),
  _ => (
    title: l.rulesStateNotConfirmed,
    body: l.rulesStateNotConfirmedBody,
    tone: AppTone.warning,
    icon: Icons.help_outline_rounded,
  ),
};

String capabilityLabel(AppLocalizations l, String key) => switch (key) {
  'app_blocking' => l.capAppBlocking,
  'app_limits' => l.capAppLimits,
  'schedules' => l.capSchedules,
  'web_filter' => l.capWebFilter,
  'restrict_now' => l.capRestrictNow,
  'usage_reporting' => l.capUsage,
  'device_lock' => l.capDeviceLock,
  _ => key,
};

({String text, AppTone tone, IconData icon}) capabilityValue(
  AppLocalizations l,
  String value,
) => switch (value) {
  'available' => (
    text: l.capAvailable,
    tone: AppTone.success,
    icon: Icons.check_circle_rounded,
  ),
  'permission_needed' => (
    text: l.capPermission,
    tone: AppTone.warning,
    icon: Icons.lock_open_rounded,
  ),
  'setup_needed' => (
    text: l.capSetup,
    tone: AppTone.warning,
    icon: Icons.build_circle_rounded,
  ),
  'unsupported' => (
    text: l.capUnsupported,
    tone: AppTone.neutral,
    icon: Icons.remove_circle_outline_rounded,
  ),
  _ => (
    text: l.capUnknown,
    tone: AppTone.neutral,
    icon: Icons.help_outline_rounded,
  ),
};

String categoryLabel(AppLocalizations l, String? c) => switch (c) {
  'games' => l.catGames,
  'social' => l.catSocial,
  'video' => l.catVideo,
  'browsers' => l.catBrowsers,
  'messaging' => l.catMessaging,
  'education' => l.catEducation,
  _ => l.catOther,
};

const ruleCategories = [
  'games',
  'social',
  'video',
  'browsers',
  'messaging',
  'education',
  'other',
];

String weekdayShort(AppLocalizations l, int d) => switch (d) {
  1 => l.weekdayShort1,
  2 => l.weekdayShort2,
  3 => l.weekdayShort3,
  4 => l.weekdayShort4,
  5 => l.weekdayShort5,
  6 => l.weekdayShort6,
  _ => l.weekdayShort7,
};

/// "Sun, Mon, Tue" in week order starting from the family's first workday,
/// or "Every day".
String daysText(AppLocalizations l, List<int> days) {
  if (days.toSet().length == 7) return l.everyDay;
  final order = [7, 1, 2, 3, 4, 5, 6];
  return order.where(days.contains).map((d) => weekdayShort(l, d)).join(', ');
}

String presetLabel(AppLocalizations l, String preset) => switch (preset) {
  'school' => l.presetSchool,
  'homework' => l.presetHomework,
  'bedtime' => l.presetBedtime,
  'weekend' => l.presetWeekend,
  _ => l.presetCustom,
};

IconData presetIcon(String preset) => switch (preset) {
  'school' => Icons.school_rounded,
  'homework' => Icons.menu_book_rounded,
  'bedtime' => Icons.bedtime_rounded,
  'weekend' => Icons.weekend_rounded,
  _ => Icons.schedule_rounded,
};

String historyKindLabel(AppLocalizations l, String kind) => switch (kind) {
  'preset' => l.rulesKindPreset,
  'restrict_now' => l.rulesKindRestrict,
  'release' => l.rulesKindRelease,
  'undo' => l.rulesKindUndo,
  'extra_time' => l.rulesKindExtra,
  'allowance' => l.rulesKindAllowance,
  _ => l.rulesKindEdit,
};

String hhmmOf(BuildContext context, DateTime t) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(t),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
