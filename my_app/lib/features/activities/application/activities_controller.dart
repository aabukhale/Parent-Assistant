import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_envelope.dart';
import '../../auth/application/auth_controller.dart';
import '../data/activities_repository.dart';
import '../data/models/activity.dart';

@immutable
class ActivitiesCatalogState {
  const ActivitiesCatalogState({
    required this.activities,
    required this.meta,
    this.loadingMore = false,
  });

  final List<Activity> activities;
  final PageMeta meta;
  final bool loadingMore;

  bool get isEmpty => activities.isEmpty;
  bool get hasMore => meta.hasMore;

  ActivitiesCatalogState copyWith({
    List<Activity>? activities,
    PageMeta? meta,
    bool? loadingMore,
  }) => ActivitiesCatalogState(
    activities: activities ?? this.activities,
    meta: meta ?? this.meta,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// The activity catalog for the active family (global + AI templates + this
/// family's own). Family-scoped: `build` watches [activeFamilyIdProvider], so a
/// family switch reloads it. A same-family child switch keeps it (the catalog is
/// not child-specific).
class ActivitiesCatalogController
    extends AsyncNotifier<ActivitiesCatalogState> {
  static const _perPage = 20;

  String? get _familyId => ref.read(activeFamilyIdProvider);

  @override
  Future<ActivitiesCatalogState> build() async {
    final familyId = ref.watch(activeFamilyIdProvider);
    if (familyId == null) {
      return ActivitiesCatalogState(
        activities: const [],
        meta: PageMeta.single(0),
      );
    }
    final page = await ref
        .read(activitiesRepositoryProvider)
        .listActivities(familyId: familyId, perPage: _perPage);
    return ActivitiesCatalogState(activities: page.items, meta: page.meta);
  }

  Future<void> refresh() async {
    final familyId = _familyId;
    if (familyId == null) return;
    state = await AsyncValue.guard(() async {
      final page = await ref
          .read(activitiesRepositoryProvider)
          .listActivities(familyId: familyId, perPage: _perPage);
      return ActivitiesCatalogState(activities: page.items, meta: page.meta);
    });
  }

  Future<void> loadMore() async {
    final familyId = _familyId;
    final current = state.valueOrNull;
    if (familyId == null ||
        current == null ||
        !current.hasMore ||
        current.loadingMore) {
      return;
    }
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref
          .read(activitiesRepositoryProvider)
          .listActivities(
            familyId: familyId,
            page: current.meta.nextPage,
            perPage: _perPage,
          );
      state = AsyncData(
        current.copyWith(
          activities: [...current.activities, ...page.items],
          meta: page.meta,
          loadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
      rethrow;
    }
  }
}

final activitiesCatalogControllerProvider =
    AsyncNotifierProvider<ActivitiesCatalogController, ActivitiesCatalogState>(
      ActivitiesCatalogController.new,
    );

/// One catalog activity by id — used by the details screen so a family activity
/// deleted elsewhere shows a 404 state rather than stale content.
final activityDetailProvider = FutureProvider.autoDispose
    .family<Activity, String>(
      (ref, activityId) =>
          ref.watch(activitiesRepositoryProvider).showActivity(activityId),
    );
