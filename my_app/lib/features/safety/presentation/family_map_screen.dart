import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/design_system.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../application/parent_safety_providers.dart';
import '../data/safety_models.dart';
import '../data/safety_repository.dart';
import 'kid_safety_widgets.dart' show placeIcon;
import 'safe_places_screen.dart';

/// OpenStreetMap tiles. The public tile server is fine for development and
/// light use; a production release needs a tile provider with an API key
/// (see docs/capability-matrix.md → external setup).
TileLayer osmTiles() => TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: 'com.example.my_app',
);

Widget osmAttribution() => RichAttributionWidget(
  attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
);

/// Parent: where each child's phone last was, how fresh and how accurate
/// that is, and why it might be missing — never a "live" claim.
class FamilyMapScreen extends ConsumerWidget {
  const FamilyMapScreen({super.key, this.focusChildId});

  final String? focusChildId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(familyMapProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.mapTitle),
        actions: [
          IconButton(
            tooltip: l.placesTitle,
            icon: const Icon(Icons.add_location_alt_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SafePlacesScreen()),
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorRetryView(
          error: e,
          onRetry: () async => ref.invalidate(familyMapProvider),
        ),
        data: (fresh) {
          final m = fresh.value;
          final located = m.children.where((c) => c.hasLocation).toList();
          final points = [
            for (final c in located)
              LatLng(c.location!.latitude, c.location!.longitude),
            for (final p in m.places)
              if (p.point != null)
                LatLng(p.point!.latitude, p.point!.longitude),
          ];
          final focus = m.children
              .where((c) => c.childId == focusChildId && c.hasLocation)
              .firstOrNull;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(familyMapProvider),
            child: ListView(
              children: [
                if (points.isNotEmpty)
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.42,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: focus != null
                            ? LatLng(
                                focus.location!.latitude,
                                focus.location!.longitude,
                              )
                            : points.first,
                        initialZoom: 14,
                        initialCameraFit: points.length > 1 && focus == null
                            ? CameraFit.coordinates(
                                coordinates: points,
                                padding: const EdgeInsets.all(48),
                                maxZoom: 16,
                              )
                            : null,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                      ),
                      children: [
                        osmTiles(),
                        CircleLayer(
                          circles: [
                            for (final p in m.places)
                              if (p.point != null)
                                CircleMarker(
                                  point: LatLng(
                                    p.point!.latitude,
                                    p.point!.longitude,
                                  ),
                                  radius: p.radiusM.toDouble(),
                                  useRadiusInMeter: true,
                                  color: context.mamily.success.background
                                      .withValues(alpha: 0.5),
                                  borderColor:
                                      context.mamily.success.foreground,
                                  borderStrokeWidth: 2,
                                ),
                            for (final c in located)
                              if ((c.location!.accuracyM ?? 0) > 30)
                                CircleMarker(
                                  point: LatLng(
                                    c.location!.latitude,
                                    c.location!.longitude,
                                  ),
                                  radius: c.location!.accuracyM!.toDouble(),
                                  useRadiusInMeter: true,
                                  color: context.mamily.info.background
                                      .withValues(alpha: 0.35),
                                  borderColor: context.mamily.info.foreground
                                      .withValues(alpha: 0.5),
                                  borderStrokeWidth: 1,
                                ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            for (final p in m.places)
                              if (p.point != null)
                                Marker(
                                  point: LatLng(
                                    p.point!.latitude,
                                    p.point!.longitude,
                                  ),
                                  width: 36,
                                  height: 36,
                                  child: Icon(
                                    placeIcon(p.kind),
                                    color: context.mamily.success.foreground,
                                  ),
                                ),
                            for (final c in located)
                              Marker(
                                point: LatLng(
                                  c.location!.latitude,
                                  c.location!.longitude,
                                ),
                                width: 56,
                                height: 56,
                                child: Semantics(
                                  label: c.childName,
                                  child: Opacity(
                                    opacity: c.status == 'fresh' ? 1 : 0.6,
                                    child: ChildAvatar(
                                      name: c.childName,
                                      avatarKey: c.avatarKey,
                                      colorHex: c.avatarColor,
                                      seed: c.childId,
                                      size: 48,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        osmAttribution(),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: AppContentFrame(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (fresh.fromCache)
                          FreshnessLine(
                            fetchedAt: fresh.fetchedAt,
                            fromCache: true,
                          ),
                        if (m.journeys.isNotEmpty) ...[
                          SectionHeader(title: l.journeysTitle),
                          for (final j in m.journeys) JourneyCard(journey: j),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        for (final c in m.children) ...[
                          ChildLocationCard(snapshot: c),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        Text(l.locNotLive, style: context.type.bodySmall),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One child: status in words, last fix age/accuracy, battery and contact,
/// and the single action that fixes a missing location.
class ChildLocationCard extends ConsumerWidget {
  const ChildLocationCard({super.key, required this.snapshot});

  final ChildLocationSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.mamily;
    final s = snapshot;
    final (title, body, tone, icon) = switch (s.status) {
      'fresh' => (l.locFresh, null, AppTone.success, Icons.location_on_rounded),
      'stale' => (l.locStale, null, AppTone.warning, Icons.history_rounded),
      'sharing_off' => (
        l.locSharingOff,
        l.locSharingOffBody(s.childName),
        AppTone.neutral,
        Icons.location_off_rounded,
      ),
      'no_device' => (
        l.locNoDevice,
        null,
        AppTone.neutral,
        Icons.phonelink_off_rounded,
      ),
      'permission_missing' => (
        l.locPermission,
        l.locPermissionBody(s.childName),
        AppTone.warning,
        Icons.lock_open_rounded,
      ),
      'location_off' => (
        l.locServicesOff,
        l.locPermissionBody(s.childName),
        AppTone.warning,
        Icons.location_disabled_rounded,
      ),
      'offline' => (
        l.locOffline,
        null,
        AppTone.neutral,
        Icons.cloud_off_rounded,
      ),
      _ => (
        l.locNoLocationYet,
        l.locNoLocationYetBody(s.childName),
        AppTone.info,
        Icons.hourglass_top_rounded,
      ),
    };

    Future<void> setSharing(bool on) async {
      try {
        await ref.read(safetyRepositoryProvider).setSharing(s.childId, on);
        ref.invalidate(familyMapProvider);
        if (context.mounted && on) {
          showResultSnack(context, l.locSharingChildSees(s.childName));
        }
      } on ApiException catch (e) {
        if (context.mounted) showResultSnack(context, e.localizedMessage(l));
      }
    }

    final lines = <String>[
      if (s.recordedAt != null)
        l.mapLastSeen(relativeTime(context, s.recordedAt!)),
      if (s.location?.accuracyM != null)
        l.mapAccuracy('${s.location!.accuracyM}'),
      if (s.batteryPct != null)
        (s.batteryCharging ?? false)
            ? l.mapBatteryCharging(s.batteryPct!)
            : l.mapBattery(s.batteryPct!),
      if (s.lastContactAt != null && s.status != 'fresh')
        l.mapLastContact(relativeTime(context, s.lastContactAt!)),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ChildAvatar(
                name: s.childName,
                avatarKey: s.avatarKey,
                colorHex: s.avatarColor,
                seed: s.childId,
                size: 44,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(s.childName, style: context.type.titleMedium),
              ),
              StatusPill(label: title, tone: tone, icon: icon),
            ],
          ),
          if (lines.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final line in lines)
              Text(
                line,
                style: context.type.bodyMedium?.copyWith(color: c.ink2),
              ),
          ],
          if (body != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(body, style: context.type.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: s.sharingEnabled
                ? TextButton(
                    onPressed: () => setSharing(false),
                    child: Text(l.locTurnOff),
                  )
                : FilledButton.icon(
                    onPressed: () => setSharing(true),
                    icon: const Icon(Icons.location_on_rounded),
                    label: Text(l.locTurnOn),
                  ),
          ),
        ],
      ),
    );
  }
}

class JourneyCard extends StatelessWidget {
  const JourneyCard({super.key, required this.journey});

  final Journey journey;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final j = journey;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(j.expectedAt),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        tone: j.isOverdue ? AppTone.warning : AppTone.info,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              j.isOverdue
                  ? Icons.schedule_rounded
                  : Icons.directions_walk_rounded,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.journeyTo(j.childName ?? '', j.destinationName),
                    style: context.type.titleSmall,
                  ),
                  Text(
                    j.isOverdue
                        ? l.journeyOverdue(time)
                        : l.journeyExpected(time),
                  ),
                  if (j.isOverdue)
                    Text(
                      l.journeyOverdueHint(j.childName ?? ''),
                      style: context.type.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
