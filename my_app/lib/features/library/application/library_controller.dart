import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_envelope.dart';
import '../../children/application/selected_child_controller.dart';
import '../data/library_repository.dart';
import '../data/models/article.dart';

/// The article categories (localized by the API). Cached; not scoped to any
/// family/child.
final libraryCategoriesProvider = FutureProvider<List<ArticleCategory>>(
  (ref) => ref.watch(libraryRepositoryProvider).categories(),
);

/// The currently-selected category `key`, or null for "all". Drives
/// [articlesControllerProvider].
final libraryCategoryFilterProvider = StateProvider<String?>((_) => null);

@immutable
class ArticlesState {
  const ArticlesState({
    required this.articles,
    required this.meta,
    required this.categoryKey,
    this.loadingMore = false,
  });

  final List<Article> articles;
  final PageMeta meta;
  final String? categoryKey;
  final bool loadingMore;

  bool get isEmpty => articles.isEmpty;
  bool get hasMore => meta.hasMore;

  ArticlesState copyWith({
    List<Article>? articles,
    PageMeta? meta,
    bool? loadingMore,
  }) => ArticlesState(
    articles: articles ?? this.articles,
    meta: meta ?? this.meta,
    categoryKey: categoryKey,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// Paginated `GET /library/articles`, re-fetched when the category filter
/// changes.
class ArticlesController extends AsyncNotifier<ArticlesState> {
  static const _perPage = 15;

  @override
  Future<ArticlesState> build() async {
    final categoryKey = ref.watch(libraryCategoryFilterProvider);
    final page = await ref
        .read(libraryRepositoryProvider)
        .listArticles(categoryKey: categoryKey, perPage: _perPage);
    return ArticlesState(
      articles: page.items,
      meta: page.meta,
      categoryKey: categoryKey,
    );
  }

  Future<void> refresh() async {
    final categoryKey = ref.read(libraryCategoryFilterProvider);
    state = await AsyncValue.guard(() async {
      final page = await ref
          .read(libraryRepositoryProvider)
          .listArticles(categoryKey: categoryKey, perPage: _perPage);
      return ArticlesState(
        articles: page.items,
        meta: page.meta,
        categoryKey: categoryKey,
      );
    });
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref
          .read(libraryRepositoryProvider)
          .listArticles(
            categoryKey: current.categoryKey,
            page: current.meta.nextPage,
            perPage: _perPage,
          );
      state = AsyncData(
        current.copyWith(
          articles: [...current.articles, ...page.items],
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

final articlesControllerProvider =
    AsyncNotifierProvider<ArticlesController, ArticlesState>(
      ArticlesController.new,
    );

/// One article's full text, keyed by slug.
final articleDetailProvider = FutureProvider.autoDispose
    .family<Article, String>(
      (ref, slug) => ref.watch(libraryRepositoryProvider).showArticle(slug),
    );

/// Age/interest recommendations for the selected child. Null child → skipped
/// (the backend requires `child_id` or `age`).
final libraryRecommendationsProvider =
    FutureProvider.autoDispose<List<Article>>((ref) {
      final child = ref.watch(selectedChildProvider);
      if (child == null) return Future.value(const []);
      return ref
          .watch(libraryRepositoryProvider)
          .recommendations(childId: child.id);
    });
