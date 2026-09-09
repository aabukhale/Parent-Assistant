import 'package:flutter/foundation.dart';

/// Backend `App\Enums\ArticleAuthorType`. `null` when the article sets no
/// author type; an unknown wire value is preserved as [unknown] rather than
/// crashing.
enum ArticleAuthorType {
  mamilyStaff,
  specialist,
  unknown;

  static ArticleAuthorType? fromWire(String? v) => switch (v) {
    null => null,
    'mamily_staff' => ArticleAuthorType.mamilyStaff,
    'specialist' => ArticleAuthorType.specialist,
    _ => ArticleAuthorType.unknown,
  };
}

@immutable
class ArticleAuthor {
  const ArticleAuthor({required this.name, required this.type});

  final String? name;
  final ArticleAuthorType? type;

  factory ArticleAuthor.fromJson(Map<String, dynamic> json) => ArticleAuthor(
    name: json['name'] as String?,
    type: ArticleAuthorType.fromWire(json['type'] as String?),
  );
}

/// A library article category (`ArticleCategoryResource`). `name` is already
/// localized by the API — never re-translate it. `key` is the stable filter
/// token passed back as `?category=`.
@immutable
class ArticleCategory {
  const ArticleCategory({
    required this.id,
    required this.key,
    required this.name,
    required this.sortOrder,
  });

  final String id;
  final String key;
  final String name;
  final int sortOrder;

  factory ArticleCategory.fromJson(Map<String, dynamic> json) =>
      ArticleCategory(
        id: '${json['id']}',
        key: '${json['key']}',
        name: json['name'] as String? ?? '',
        sortOrder: (json['sort_order'] as num?)?.round() ?? 0,
      );
}

/// A parent-library article (`ArticleResource`).
///
/// `body` is `null` in list / recommendation responses and a full string in the
/// detail response — the UI must treat "no body" as "open the article", not as
/// an empty article. `title` / `excerpt` / `body` are API-localized.
@immutable
class Article {
  const Article({
    required this.id,
    required this.slug,
    required this.title,
    required this.excerpt,
    required this.body,
    required this.author,
    required this.minAge,
    required this.maxAge,
    required this.publishedAt,
    required this.categories,
  });

  final String id;
  final String slug;
  final String title;
  final String? excerpt;
  final String? body;
  final ArticleAuthor author;
  final int? minAge;
  final int? maxAge;
  final DateTime? publishedAt;
  final List<ArticleCategory> categories;

  bool get hasBody => (body ?? '').isNotEmpty;

  factory Article.fromJson(Map<String, dynamic> json) {
    final rawAuthor = json['author'];
    final rawCategories = (json['categories'] as List?) ?? const [];
    return Article(
      id: '${json['id']}',
      slug: '${json['slug']}',
      title: json['title'] as String? ?? '',
      excerpt: json['excerpt'] as String?,
      body: json['body'] as String?,
      author: rawAuthor is Map<String, dynamic>
          ? ArticleAuthor.fromJson(rawAuthor)
          : const ArticleAuthor(name: null, type: null),
      minAge: (json['min_age'] as num?)?.round(),
      maxAge: (json['max_age'] as num?)?.round(),
      publishedAt: DateTime.tryParse('${json['published_at']}'),
      categories: rawCategories
          .whereType<Map>()
          .map((m) => ArticleCategory.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }
}
