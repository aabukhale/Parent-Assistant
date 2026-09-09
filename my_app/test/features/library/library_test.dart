import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/errors/api_exception.dart';
import 'package:my_app/features/library/application/library_controller.dart';
import 'package:my_app/features/library/data/library_repository.dart';
import 'package:my_app/features/library/data/models/article.dart';
import 'package:my_app/features/library/presentation/library_screen.dart';
import 'package:my_app/l10n/app_localizations.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

void main() {
  group('models', () {
    test(
      'Article: list row has null body → hasBody false, detail has body',
      () {
        final row = Article.fromJson(Fixtures.articleJson());
        expect(row.body, isNull);
        expect(row.hasBody, isFalse);
        expect(row.excerpt, isNotNull);
        final detail = Article.fromJson(
          Fixtures.articleJson(body: 'Full text here'),
        );
        expect(detail.hasBody, isTrue);
      },
    );

    test('author type: known / null / unknown', () {
      expect(
        Article.fromJson(
          Fixtures.articleJson(authorType: 'mamily_staff'),
        ).author.type,
        ArticleAuthorType.mamilyStaff,
      );
      expect(
        Article.fromJson(Fixtures.articleJson(authorType: null)).author.type,
        isNull,
      );
      expect(
        Article.fromJson(Fixtures.articleJson(authorType: 'robot')).author.type,
        ArticleAuthorType.unknown,
      );
    });

    test('null age bounds and empty categories tolerated', () {
      final a = Article.fromJson(
        Fixtures.articleJson(minAge: null, maxAge: null, categories: const []),
      );
      expect(a.minAge, isNull);
      expect(a.categories, isEmpty);
    });

    test('ArticleCategory parses key + localized name', () {
      final c = ArticleCategory.fromJson(
        Fixtures.articleCategoryJson(key: 'sleep', name: 'النوم'),
      );
      expect(c.key, 'sleep');
      expect(c.name, 'النوم');
    });
  });

  group('repository', () {
    late TestApi api;
    late LibraryRepository repo;

    setUp(() {
      api = TestApi.create(token: 'tok');
      repo = api.container.read(libraryRepositoryProvider);
    });
    tearDown(() => api.dispose());

    test('categories: plain array, no paging', () async {
      api.adapter.onGet(
        '/library/categories',
        (s) => s.reply(200, Fixtures.articleCategoriesEnvelope()),
      );
      final cats = await repo.categories();
      expect(cats.map((c) => c.key), ['behaviour', 'sleep']);
    });

    test('listArticles: category filter passed as ?category=key', () async {
      api.adapter.onGet(
        '/library/articles',
        (s) => s.reply(200, Fixtures.articlesPage([Fixtures.articleJson()])),
      );
      await repo.listArticles(categoryKey: 'sleep');
      expect(api.lastRequest.uri.queryParameters['category'], 'sleep');
    });

    test('showArticle: GET by slug, 404 for unpublished', () async {
      api.adapter.onGet(
        '/library/articles/my-slug',
        (s) => s.reply(
          200,
          Fixtures.articleEnvelope(
            article: Fixtures.articleJson(slug: 'my-slug', body: 'B'),
          ),
        ),
      );
      expect((await repo.showArticle('my-slug')).hasBody, isTrue);

      api.adapter.onGet(
        '/library/articles/draft',
        (s) => s.reply(404, {'success': false, 'message': 'Not found.'}),
      );
      try {
        await repo.showArticle('draft');
        fail('expected');
      } on ApiException catch (e) {
        expect(e.kind, ApiErrorKind.notFound);
      }
    });

    test('recommendations: child_id forwarded; empty list tolerated', () async {
      api.adapter.onGet(
        '/library/recommendations',
        (s) => s.reply(200, Fixtures.recommendationsEnvelope(const [])),
      );
      final recs = await repo.recommendations(childId: 'child-1');
      expect(recs, isEmpty);
      expect(api.lastRequest.uri.queryParameters['child_id'], 'child-1');
    });

    test('recommendations: 422 when neither child_id nor age', () async {
      api.adapter.onGet(
        '/library/recommendations',
        (s) => s.reply(422, {
          'success': false,
          'message': 'Provide child_id or age.',
        }),
      );
      try {
        await repo.recommendations();
        fail('expected');
      } on ApiException catch (e) {
        expect(e.kind, ApiErrorKind.validation);
      }
    });
  });

  group('controller', () {
    test('articles reload when the category filter changes', () async {
      final api = TestApi.create(token: 'tok');
      addTearDown(api.dispose);
      api.adapter.onGet(
        '/library/articles',
        (s) => s.reply(
          200,
          Fixtures.articlesPage([Fixtures.articleJson(id: 'all')]),
        ),
      );
      final sub = api.container.listen(articlesControllerProvider, (_, _) {});
      addTearDown(sub.close);
      expect(
        (await api.container.read(
          articlesControllerProvider.future,
        )).articles.single.id,
        'all',
      );

      api.adapter.onGet(
        '/library/articles',
        (s) => s.reply(
          200,
          Fixtures.articlesPage([Fixtures.articleJson(id: 'sleep-only')]),
        ),
      );
      api.container.read(libraryCategoryFilterProvider.notifier).state =
          'sleep';
      await Future<void>.delayed(Duration.zero);
      expect(
        (await api.container.read(
          articlesControllerProvider.future,
        )).articles.single.id,
        'sleep-only',
      );
      expect(api.lastRequest.uri.queryParameters['category'], 'sleep');
    });
  });

  group('widget', () {
    Widget host(TestApi api, {String locale = 'en'}) =>
        UncontrolledProviderScope(
          container: api.container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale(locale),
            home: const LibraryScreen(),
          ),
        );

    testWidgets('renders real articles + category chips', (tester) async {
      final l = lookupAppLocalizations(const Locale('en'));
      final api = TestApi.create(token: 'tok', locale: 'en');
      addTearDown(api.dispose);
      api.adapter
        ..onGet(
          '/library/categories',
          (s) => s.reply(200, Fixtures.articleCategoriesEnvelope()),
        )
        ..onGet(
          '/library/articles',
          (s) => s.reply(
            200,
            Fixtures.articlesPage([
              Fixtures.articleJson(title: 'Bedtime routines'),
            ]),
          ),
        );
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(host(api));
      await tester.pumpAndSettle();

      expect(find.text('Bedtime routines'), findsOneWidget);
      expect(find.text('Behaviour'), findsWidgets);
      expect(find.text(l.libraryAllCategories), findsOneWidget);
    });

    testWidgets('empty + error/retry', (tester) async {
      final l = lookupAppLocalizations(const Locale('en'));
      final api = TestApi.create(token: 'tok', locale: 'en');
      addTearDown(api.dispose);
      api.adapter
        ..onGet(
          '/library/categories',
          (s) => s.reply(200, Fixtures.articleCategoriesEnvelope(const [])),
        )
        ..onGet(
          '/library/articles',
          (s) => s.reply(500, {'success': false, 'message': 'x'}),
        );
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(host(api));
      await tester.pumpAndSettle();
      expect(find.text(l.commonRetry), findsOneWidget);
    });
  });
}
