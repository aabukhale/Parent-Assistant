import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/design_system.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../application/parent_safety_providers.dart';
import '../data/safety_models.dart';
import '../data/safety_repository.dart';
import 'family_map_screen.dart';
import 'kid_safety_widgets.dart' show placeIcon;

class SafePlacesScreen extends ConsumerWidget {
  const SafePlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(safePlacesProvider);
    Future<void> edit([SafePlace? p]) async {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => SafePlaceEditor(place: p)),
      );
      ref
        ..invalidate(safePlacesProvider)
        ..invalidate(familyMapProvider);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.placesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: edit,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: Text(l.placeAdd),
      ),
      body: AppContentFrame(
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorRetryView(
            error: e,
            onRetry: () async => ref.invalidate(safePlacesProvider),
          ),
          data: (places) => places.isEmpty
              ? EmptyView(icon: Icons.home_rounded, message: l.placesEmpty)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    96,
                  ),
                  children: [
                    for (final p in places)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppListTile(
                          leading: IconBadge(
                            icon: placeIcon(p.kind),
                            tone: AppTone.success,
                          ),
                          title: p.name,
                          subtitle: [
                            l.placeRadius('${p.radiusM}'),
                            if (p.notifyArrive) l.placeNotifyArrive,
                            if (p.notifyLeave) l.placeNotifyLeave,
                          ].join(' · '),
                          onTap: () => edit(p),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    Text(l.placeNoGuarantee, style: context.type.bodySmall),
                  ],
                ),
        ),
      ),
    );
  }
}

class SafePlaceEditor extends ConsumerStatefulWidget {
  const SafePlaceEditor({super.key, this.place});

  final SafePlace? place;

  @override
  ConsumerState<SafePlaceEditor> createState() => _SafePlaceEditorState();
}

class _SafePlaceEditorState extends ConsumerState<SafePlaceEditor> {
  late final _name = TextEditingController(text: widget.place?.name ?? '');
  late String _kind = widget.place?.kind ?? 'home';
  late LatLng? _point = widget.place?.point == null
      ? null
      : LatLng(widget.place!.point!.latitude, widget.place!.point!.longitude);
  late double _radius = (widget.place?.radiusM ?? 150).toDouble();
  late bool _arrive = widget.place?.notifyArrive ?? true;
  late bool _leave = widget.place?.notifyLeave ?? false;
  final _map = MapController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 10),
        ),
      );
      setState(() => _point = LatLng(pos.latitude, pos.longitude));
      _map.move(_point!, 16);
    } catch (_) {}
  }

  Future<void> _save() async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      await ref
          .read(safetyRepositoryProvider)
          .savePlace(
            SafePlace(
              id: widget.place?.id ?? '',
              name: _name.text.trim(),
              kind: _kind,
              point: GeoPoint(
                latitude: _point!.latitude,
                longitude: _point!.longitude,
              ),
              radiusM: _radius.round(),
              notifyArrive: _arrive,
              notifyLeave: _leave,
              childIds: widget.place?.childIds,
            ),
            id: widget.place?.id,
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) showResultSnack(context, e.localizedMessage(l));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final ok = await confirmAction(
      context,
      title: l.commonDelete,
      confirmLabel: l.commonDelete,
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(safetyRepositoryProvider).deletePlace(widget.place!.id);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) showResultSnack(context, e.localizedMessage(l));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    final ready = _point != null && _name.text.trim().isNotEmpty && !_busy;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.place == null ? l.placeAdd : l.placeEdit),
        actions: [
          if (widget.place != null)
            IconButton(
              tooltip: l.commonDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          children: [
            SizedBox(
              height: 300,
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: _point ?? const LatLng(31.7767, 35.2345),
                  initialZoom: _point == null ? 7 : 16,
                  onTap: (_, p) => setState(() => _point = p),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  osmTiles(),
                  if (_point != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: _point!,
                          radius: _radius,
                          useRadiusInMeter: true,
                          color: c.success.background.withValues(alpha: 0.5),
                          borderColor: c.success.foreground,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                  if (_point != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _point!,
                          width: 40,
                          height: 40,
                          child: Icon(
                            placeIcon(_kind),
                            color: c.success.foreground,
                            size: 36,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.placeTapMap, style: context.type.bodyMedium),
                  TextButton.icon(
                    onPressed: _useMyLocation,
                    icon: const Icon(Icons.my_location_rounded),
                    label: Text(l.placeUseMyLocation),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _name,
                    maxLength: 80,
                    decoration: InputDecoration(labelText: l.placeName),
                    onChanged: (_) => setState(() {}),
                  ),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      for (final (k, label) in [
                        ('home', l.placeKindHome),
                        ('school', l.placeKindSchool),
                        ('other', l.placeKindOther),
                      ])
                        ChoiceChip(
                          avatar: Icon(placeIcon(k), size: 18),
                          label: Text(label),
                          selected: _kind == k,
                          onSelected: (_) => setState(() => _kind = k),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l.placeRadius('${_radius.round()}'),
                    style: context.type.titleSmall,
                  ),
                  Slider(
                    value: _radius,
                    min: 100,
                    max: 1000,
                    divisions: 18,
                    label: '${_radius.round()} m',
                    onChanged: (v) => setState(() => _radius = v),
                  ),
                  SwitchListTile(
                    value: _arrive,
                    title: Text(l.placeNotifyArrive),
                    onChanged: (v) => setState(() => _arrive = v),
                  ),
                  SwitchListTile(
                    value: _leave,
                    title: Text(l.placeNotifyLeave),
                    onChanged: (v) => setState(() => _leave = v),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  NoticeBanner(tone: AppTone.info, message: l.placeNoGuarantee),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: ready ? _save : null,
                    child: Text(l.commonSave),
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
