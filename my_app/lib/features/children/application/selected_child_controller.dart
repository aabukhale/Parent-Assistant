import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/models/child.dart';
import 'children_controller.dart';

/// The centrally-tracked selected child UUID.
///
/// * Resets whenever the active family changes (build re-runs on the family id).
/// * Auto-selects the first child once the family's list is available, and
///   drops a selection that no longer exists (after delete / status filter).
/// * In-memory only for now — on a cold start it re-selects the first child
///   rather than persisting the previous choice (revisit if product wants it
///   sticky).
class SelectedChildController extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(activeFamilyIdProvider); // reset on family switch

    ref.listen(childrenControllerProvider, (_, next) {
      final resolved = _resolve(next, state);
      if (resolved != state) state = resolved;
    });

    return _resolve(ref.read(childrenControllerProvider), null);
  }

  static String? _resolve(
    AsyncValue<ChildrenListState> async,
    String? current,
  ) {
    final list = async.valueOrNull;
    if (list == null) return current;
    final ids = list.children.map((c) => c.id).toSet();
    if (current != null && ids.contains(current)) return current;
    return list.children.isEmpty ? null : list.children.first.id;
  }

  void select(String childId) => state = childId;

  void clear() => state = null;
}

final selectedChildIdProvider =
    NotifierProvider<SelectedChildController, String?>(
      SelectedChildController.new,
    );

/// The resolved selected [Child] from the loaded list, or null.
final selectedChildProvider = Provider<Child?>((ref) {
  final id = ref.watch(selectedChildIdProvider);
  final list = ref.watch(childrenControllerProvider).valueOrNull;
  if (id == null || list == null) return null;
  for (final child in list.children) {
    if (child.id == id) return child;
  }
  return null;
});

/// The invalidation key for **every** child-scoped provider added in later
/// phases. Watch it (or key a `.family` provider by [ChildScope.childId]) so the
/// provider rebuilds when the active family or the selected child changes.
typedef ChildScope = ({String? familyId, String? childId});

final childScopeProvider = Provider<ChildScope>(
  (ref) => (
    familyId: ref.watch(activeFamilyIdProvider),
    childId: ref.watch(selectedChildIdProvider),
  ),
);
