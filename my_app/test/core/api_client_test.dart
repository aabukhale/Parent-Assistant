import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/core/api/api_client.dart';
import 'package:my_app/core/api/api_envelope.dart';
import 'package:my_app/core/errors/api_exception.dart';
import 'package:my_app/core/providers.dart';

import '../support/fixtures.dart';
import '../support/test_api.dart';

void main() {
  late TestApi api;
  late ApiClient client;

  setUp(() {
    api = TestApi.create(token: 'tok_abc123', locale: 'he');
    client = api.container.read(apiClientProvider);
  });
  tearDown(() => api.dispose());

  test('uses the configured base URL', () {
    final dio = api.container.read(dioProvider);
    expect(dio.options.baseUrl, endsWith('/api/v1'));
  });

  test('attaches Authorization, Accept and Accept-Language headers', () async {
    api.adapter.onGet(
      '/interests',
      (s) => s.reply(200, {'success': true, 'data': []}),
    );

    await client.get('/interests');

    final headers = api.lastRequest.headers;
    expect(headers['Authorization'], 'Bearer tok_abc123');
    expect(headers['Accept'], 'application/json');
    expect(headers['Accept-Language'], 'he');
  });

  test('omits Authorization when there is no token', () async {
    final anon = TestApi.create(token: null);
    addTearDown(anon.dispose);
    anon.adapter.onGet(
      '/interests',
      (s) => s.reply(200, {'success': true, 'data': []}),
    );

    await anon.container.read(apiClientProvider).get('/interests');

    expect(anon.lastRequest.headers.containsKey('Authorization'), isFalse);
  });

  test('parses a paginated list envelope into Paginated<T>', () async {
    api.adapter.onGet(
      '/library/articles',
      (s) => s.reply(
        200,
        Fixtures.paginated(
          [
            {'id': 'a1', 'title': 'One'},
            {'id': 'a2', 'title': 'Two'},
          ],
          currentPage: 1,
          lastPage: 3,
          total: 42,
        ),
      ),
    );

    final envelope = await client.get('/library/articles');
    final page = Paginated.from<Map<String, dynamic>>(envelope, (j) => j);

    expect(page.items, hasLength(2));
    expect(page.meta.total, 42);
    expect(page.meta.hasMore, isTrue);
    expect(page.meta.nextPage, 2);
  });

  test('treats a plain data array (no meta) as a single page', () async {
    api.adapter.onGet(
      '/interests',
      (s) => s.reply(200, {
        'success': true,
        'data': [
          {'id': 'i1', 'name': 'الحيوانات'},
        ],
      }),
    );

    final page = Paginated.from<Map<String, dynamic>>(
      await client.get('/interests'),
      (j) => j,
    );
    expect(page.meta.hasMore, isFalse);
    expect(page.items.single['id'], 'i1');
  });

  test('maps 422 to a validation ApiException with field errors', () async {
    api.adapter.onPost(
      '/auth/register',
      (s) => s.reply(
        422,
        Fixtures.validationError(
          errors: {
            'family_name': ['The family name field is required.'],
          },
        ),
      ),
      data: Matchers.any,
    );

    final error = await _capture(() => client.post('/auth/register', body: {}));
    expect(error.kind, ApiErrorKind.validation);
    expect(error.statusCode, 422);
    expect(
      error.fieldError('family_name'),
      'The family name field is required.',
    );
  });

  test('maps status codes to the right ApiErrorKind', () async {
    Future<ApiErrorKind> kindFor(int status) async {
      final t = TestApi.create(token: 't');
      addTearDown(t.dispose);
      t.adapter.onGet(
        '/x',
        (s) => s.reply(status, {'success': false, 'message': 'nope'}),
      );
      final err = await _capture(
        () => t.container.read(apiClientProvider).get('/x'),
      );
      return err.kind;
    }

    expect(await kindFor(401), ApiErrorKind.unauthorized);
    expect(await kindFor(403), ApiErrorKind.forbidden);
    expect(await kindFor(404), ApiErrorKind.notFound);
    expect(await kindFor(409), ApiErrorKind.conflict);
    expect(await kindFor(429), ApiErrorKind.rateLimited);
    expect(await kindFor(503), ApiErrorKind.unavailable);
    expect(await kindFor(500), ApiErrorKind.server);
  });

  test('a 401 bumps the unauthorized signal exactly once', () async {
    expect(api.unauthorizedSignals, 0);
    api.adapter.onGet(
      '/me',
      (s) => s.reply(401, {'success': false, 'message': 'Unauthenticated.'}),
    );

    await _capture(() => client.get('/me'));

    expect(api.unauthorizedSignals, 1);
    expect(await api.storage.readToken(), isNull, reason: 'token wiped on 401');
  });
}

/// Runs [action], expecting it to throw an [ApiException], and returns it.
Future<ApiException> _capture(Future<void> Function() action) async {
  try {
    await action();
    fail('expected an ApiException');
  } on ApiException catch (e) {
    return e;
  }
}
