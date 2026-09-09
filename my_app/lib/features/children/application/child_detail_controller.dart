import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/children_repository.dart';
import '../data/models/child.dart';

/// `GET /families/{family}/children/{child}` for one child, keyed by child UUID.
///
/// Child-scoped: rebuilds if the active family changes; invalidated by
/// [ChildrenController.updateChild] / `deleteChild`.
final childDetailProvider = FutureProvider.autoDispose.family<Child, String>((
  ref,
  childId,
) {
  final familyId = ref.watch(activeFamilyIdProvider);
  if (familyId == null) {
    throw StateError('No active family');
  }
  return ref.watch(childrenRepositoryProvider).show(familyId, childId);
});
