import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/design_system.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../family_hub/application/hub_providers.dart';
import '../application/parent_safety_providers.dart';
import '../data/safety_models.dart';
import '../data/safety_repository.dart';
import 'access_history_screen.dart';
import 'family_map_screen.dart';
import 'safety_centre_screen.dart';

String checkinKindLabel(AppLocalizations l, String kind) => switch (kind) {
  'arrived' => l.kidCheckArrived,
  'pick_me_up' => l.kidCheckPickMeUp,
  'call_me' => l.kidCheckCallMe,
  _ => l.kidCheckOkay,
};

/// Parent "Safety": anything urgent first (help requests, pick-me-up/call-me,
/// late check-ins), then the map, safety centre and access history.
class ParentSafetyScreen extends ConsumerWidget {
  const ParentSafetyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final alerts = ref.watch(openHelpAlertsProvider);
    final checkins = ref.watch(safetyCheckinsProvider);
    final map = ref.watch(familyMapProvider).valueOrNull?.value;
    void open(Widget w) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));
    Future<void> refresh() async {
      ref
        ..invalidate(openHelpAlertsProvider)
        ..invalidate(safetyCheckinsProvider)
        ..invalidate(familyMapProvider);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.safetyTitle)),
      body: AppContentFrame(
        child: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              ...alerts.when(
                loading: () => [const LoadingView()],
                error: (e, _) => [ErrorRetryView(error: e, onRetry: refresh)],
                data: (list) => list.isEmpty
                    ? [
                        NoticeBanner(
                          tone: AppTone.success,
                          icon: Icons.check_circle_rounded,
                          message: l.safetyNoAlerts,
                        ),
                      ]
                    : [for (final a in list) HelpAlertCard(alert: a)],
              ),
              for (final j
                  in map?.journeys.where((j) => j.isOverdue) ??
                      const <Journey>[])
                JourneyCard(journey: j),
              const SizedBox(height: AppSpacing.lg),
              NavTileRow(
                items: [
                  (
                    Icons.map_rounded,
                    l.mapTitle,
                    () => open(const FamilyMapScreen()),
                  ),
                  (
                    Icons.health_and_safety_rounded,
                    l.safetyCentreTitle,
                    () => open(const SafetyCentreScreen()),
                  ),
                  (
                    Icons.manage_search_rounded,
                    l.accessHistory,
                    () => open(const AccessHistoryScreen()),
                  ),
                ],
              ),
              SectionHeader(
                title: l.safetyCheckins,
                padding: const EdgeInsets.only(
                  top: AppSpacing.xl,
                  bottom: AppSpacing.md,
                ),
              ),
              ...checkins.when(
                loading: () => [const LoadingView()],
                error: (e, _) => [ErrorRetryView(error: e, onRetry: refresh)],
                data: (list) => list.isEmpty
                    ? [Text(l.commonEmpty, style: context.type.bodyMedium)]
                    : [for (final c in list.take(20)) _CheckinTile(checkin: c)],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NavTileRow extends StatelessWidget {
  const NavTileRow({super.key, required this.items});

  final List<(IconData, String, VoidCallback)> items;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final (icon, label, onTap) in items)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppListTile(
            leading: IconBadge(icon: icon, tone: AppTone.info),
            title: label,
            onTap: onTap,
          ),
        ),
    ],
  );
}

class HelpAlertCard extends ConsumerWidget {
  const HelpAlertCard({super.key, required this.alert});

  final HelpAlert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final a = alert;
    Future<void> act(Future<HelpAlert> Function() f) async {
      try {
        await f();
        ref
          ..invalidate(openHelpAlertsProvider)
          ..invalidate(familyInboxProvider);
      } on ApiException catch (e) {
        if (context.mounted) showResultSnack(context, e.localizedMessage(l));
      }
    }

    final repo = ref.read(safetyRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        tone: a.isOpen ? AppTone.danger : AppTone.warning,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.sos_rounded, size: 32),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l.safetyHelpNow(a.childName ?? ''),
                    style: context.type.titleMedium,
                  ),
                ),
              ],
            ),
            if (a.createdAt != null)
              Text(
                relativeTime(context, a.createdAt!),
                style: context.type.bodySmall,
              ),
            if ((a.message ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('“${a.message}”', style: context.type.bodyLarge),
            ],
            if (a.batteryPct != null)
              Text(l.mapBattery(a.batteryPct!), style: context.type.bodySmall),
            if (a.acknowledgedBy != null)
              Text(
                l.safetyHelpSeenBy(a.acknowledgedBy!),
                style: context.type.bodySmall,
              ),
            if (a.location != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(l.safetyHelpLocation, style: context.type.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: AppRadii.mediumAll,
                child: SizedBox(
                  height: 160,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(
                        a.location!.latitude,
                        a.location!.longitude,
                      ),
                      initialZoom: 15,
                    ),
                    children: [
                      osmTiles(),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                              a.location!.latitude,
                              a.location!.longitude,
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Colors.red,
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                      osmAttribution(),
                    ],
                  ),
                ),
              ),
              if (a.location!.accuracyM != null)
                Text(
                  l.mapAccuracy('${a.location!.accuracyM}'),
                  style: context.type.bodySmall,
                ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (a.isOpen)
              FilledButton.icon(
                onPressed: () => act(() => repo.acknowledgeHelp(a.id)),
                icon: const Icon(Icons.visibility_rounded),
                label: Text(l.safetyHelpSeen),
              ),
            OutlinedButton(
              onPressed: () => act(() => repo.resolveHelp(a.id)),
              child: Text(l.safetyHelpResolve),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckinTile extends ConsumerWidget {
  const _CheckinTile({required this.checkin});

  final SafetyCheckin checkin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = checkin;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppListTile(
        leading: IconBadge(
          icon: switch (c.kind) {
            'arrived' => Icons.where_to_vote_rounded,
            'pick_me_up' => Icons.directions_car_rounded,
            'call_me' => Icons.phone_callback_rounded,
            _ => Icons.thumb_up_alt_rounded,
          },
          tone: c.isUrgent && c.acknowledgedAt == null
              ? AppTone.warning
              : AppTone.success,
        ),
        title: l.safetyCheckinLine(
          c.childName ?? '',
          checkinKindLabel(l, c.kind),
        ),
        subtitle: [
          if (c.createdAt != null) relativeTime(context, c.createdAt!),
          if ((c.note ?? '').isNotEmpty) c.note!,
        ].join(' · '),
        trailing: c.acknowledgedAt != null
            ? StatusPill(
                label: l.safetyAcked,
                tone: AppTone.success,
                icon: Icons.check_rounded,
              )
            : TextButton(
                onPressed: () async {
                  try {
                    await ref
                        .read(safetyRepositoryProvider)
                        .acknowledgeCheckin(c.id);
                    ref.invalidate(safetyCheckinsProvider);
                  } on ApiException catch (e) {
                    if (context.mounted) {
                      showResultSnack(context, e.localizedMessage(l));
                    }
                  }
                },
                child: Text(l.safetyAck),
              ),
      ),
    );
  }
}
