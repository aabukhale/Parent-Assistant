import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_envelope.dart';
import '../../children/application/selected_child_controller.dart';
import '../data/games_repository.dart';
import '../data/models/game.dart';

@immutable
class GamesCatalogState {
  const GamesCatalogState({
    required this.games,
    required this.meta,
    this.loadingMore = false,
  });

  final List<Game> games;
  final PageMeta meta;
  final bool loadingMore;

  bool get isEmpty => games.isEmpty;
  bool get hasMore => meta.hasMore;

  GamesCatalogState copyWith({
    List<Game>? games,
    PageMeta? meta,
    bool? loadingMore,
  }) => GamesCatalogState(
    games: games ?? this.games,
    meta: meta ?? this.meta,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// The parent-preview game catalog. Passes the selected child's age so the
/// listing matches; a same-family child switch just re-filters by age.
class GamesCatalogController extends AsyncNotifier<GamesCatalogState> {
  static const _perPage = 20;
  int? _age;

  @override
  Future<GamesCatalogState> build() async {
    _age = ref.watch(selectedChildProvider)?.age;
    final page = await ref
        .read(gamesRepositoryProvider)
        .listGames(age: _age, perPage: _perPage);
    return GamesCatalogState(games: page.items, meta: page.meta);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      final page = await ref
          .read(gamesRepositoryProvider)
          .listGames(age: _age, perPage: _perPage);
      return GamesCatalogState(games: page.items, meta: page.meta);
    });
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref
          .read(gamesRepositoryProvider)
          .listGames(age: _age, page: current.meta.nextPage, perPage: _perPage);
      state = AsyncData(
        current.copyWith(
          games: [...current.games, ...page.items],
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

final gamesCatalogControllerProvider =
    AsyncNotifierProvider<GamesCatalogController, GamesCatalogState>(
      GamesCatalogController.new,
    );

/// One game's details, keyed by **slug** (`GET /games/{game}` binds by slug,
/// not id — see `Game::getRouteKeyName()`).
final gameDetailProvider = FutureProvider.autoDispose.family<Game, String>(
  (ref, slug) => ref.watch(gamesRepositoryProvider).showGame(slug),
);

/// Per-child game progress (one row per game played). Child-scoped.
final gameProgressProvider = FutureProvider.autoDispose<List<GameProgress>>((
  ref,
) {
  final scope = ref.watch(childScopeProvider);
  if (scope.familyId == null || scope.childId == null) {
    return Future.value(const []);
  }
  return ref
      .watch(gamesRepositoryProvider)
      .progress(scope.familyId!, scope.childId!);
});
