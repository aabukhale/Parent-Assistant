import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/providers.dart';
import 'models/interest.dart';

/// `GET /interests` — bounded, localized reference data (~10 rows, plain `data`
/// array, no pagination).
class InterestsRepository {
  InterestsRepository(this._client);

  final ApiClient _client;

  Future<List<Interest>> list() async {
    final envelope = await _client.get('/interests');
    return envelope.dataList
        .whereType<Map<String, dynamic>>()
        .map(Interest.fromJson)
        .toList(growable: false);
  }
}

final interestsRepositoryProvider = Provider<InterestsRepository>(
  (ref) => InterestsRepository(ref.watch(apiClientProvider)),
);

/// Cached for the session; re-fetched when the UI locale changes so the
/// localized names stay correct.
final interestsProvider = FutureProvider<List<Interest>>((ref) {
  ref.watch(localeControllerProvider);
  return ref.watch(interestsRepositoryProvider).list();
});
