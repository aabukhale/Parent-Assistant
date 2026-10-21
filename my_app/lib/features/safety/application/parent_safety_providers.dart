import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../kid/data/kid_models.dart';
import '../data/safety_models.dart';
import '../data/safety_repository.dart';

final familyMapProvider = FutureProvider.autoDispose<Fresh<FamilyMap>>(
  (ref) => ref.watch(safetyRepositoryProvider).map(),
);

final safePlacesProvider = FutureProvider.autoDispose<List<SafePlace>>(
  (ref) => ref.watch(safetyRepositoryProvider).places(),
);

final openHelpAlertsProvider = FutureProvider.autoDispose<List<HelpAlert>>(
  (ref) => ref.watch(safetyRepositoryProvider).helpAlerts(),
);

final safetyCheckinsProvider = FutureProvider.autoDispose<List<SafetyCheckin>>(
  (ref) => ref.watch(safetyRepositoryProvider).checkins(),
);

final parentSafetyCentreProvider =
    FutureProvider.autoDispose<Fresh<SafetyCentre>>(
      (ref) => ref.watch(safetyRepositoryProvider).centre(),
    );

final accessLogProvider = FutureProvider.autoDispose
    .family<List<AccessLogEntry>, String?>(
      (ref, childId) =>
          ref.watch(safetyRepositoryProvider).accessLog(childId: childId),
    );

final childAgreementsProvider = FutureProvider.autoDispose
    .family<
      ({List<Agreement> agreements, List<LessonProgress> lessons}),
      String
    >(
      (ref, childId) => ref.watch(safetyRepositoryProvider).agreements(childId),
    );
