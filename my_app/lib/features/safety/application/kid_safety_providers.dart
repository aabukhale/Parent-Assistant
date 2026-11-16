import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../kid/data/kid_models.dart';
import '../data/safety_models.dart';
import '../data/safety_repository.dart';

final kidSafetyCentreProvider = FutureProvider.autoDispose<Fresh<SafetyCentre>>(
  (ref) => ref.watch(kidSafetyRepositoryProvider).centre(),
);

final kidJourneyProvider = FutureProvider.autoDispose<Journey?>(
  (ref) => ref.watch(kidSafetyRepositoryProvider).activeJourney(),
);

final kidLocationSettingsProvider =
    FutureProvider.autoDispose<({bool sharing, bool informed})>(
      (ref) => ref.watch(kidSafetyRepositoryProvider).locationSettings(),
    );

final kidAgreementsProvider = FutureProvider.autoDispose<List<Agreement>>(
  (ref) => ref.watch(kidSafetyRepositoryProvider).agreements(),
);

final kidLessonsProvider = FutureProvider.autoDispose<List<LessonProgress>>(
  (ref) => ref.watch(kidSafetyRepositoryProvider).lessons(),
);

final kidSafetyCheckinsProvider =
    FutureProvider.autoDispose<List<SafetyCheckin>>(
      (ref) => ref.watch(kidSafetyRepositoryProvider).checkins(),
    );

/// The lesson keys the app ships content for (same keys as the backend).
const lessonKeys = [
  'scams',
  'bullying',
  'passwords',
  'photo_sharing',
  'strangers_online',
];
