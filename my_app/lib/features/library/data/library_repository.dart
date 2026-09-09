import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_envelope.dart';
import '../../../core/providers.dart';
import 'models/article.dart';

/// HTTP for the read-only parent library (`LibraryController`). Every endpoint
/// is available to any authenticated user; there is no family/child tenancy on
/// the catalog itself (recommendations optionally take a `child_id` the caller
/// must be able to access). No engagement endpoints exist — bookmarks, likes,
/// views and reading progress are **not** part of this backend.
class LibraryRepository {
  LibraryRepository(this._client);

  final ApiClient _client;

  /// Plain array, no pagination.
  Future<List<ArticleCategory>> categories() async {
    final envelope = await _client.get('/library/categories');
    return envelope.dataList
        .whereType<Map<String, dynamic>>()
        .map(ArticleCategory.fromJson)
        .toList(growable: false);
  }

  /// Paginated. [categoryKey] filters by the category's stable `key`. List rows
  /// carry `body: null` — use [showArticle] for the full text.
  Future<Paginated<Article>> listArticles({
    String? categoryKey,
    int page = 1,
    int perPage = 15,
  }) async {
    final envelope = await _client.get(
      '/library/articles',
      query: {'page': page, 'per_page': perPage, 'category': ?categoryKey},
    );
    return Paginated.from<Article>(envelope, Article.fromJson);
  }

  /// The route key is the **slug**. 404 when the article is not published.
  Future<Article> showArticle(String slug) async {
    final envelope = await _client.get('/library/articles/$slug');
    return Article.fromJson(envelope.dataMap);
  }

  /// Up to 10 age/interest-matched articles (no body). Pass a [childId] the
  /// caller can access, or an explicit [age]. 422 if neither is given.
  Future<List<Article>> recommendations({String? childId, int? age}) async {
    final envelope = await _client.get(
      '/library/recommendations',
      query: {'child_id': ?childId, 'age': ?age},
    );
    return envelope.dataList
        .whereType<Map<String, dynamic>>()
        .map(Article.fromJson)
        .toList(growable: false);
  }
}

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(ref.watch(apiClientProvider)),
);
