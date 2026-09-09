import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/core/errors/api_exception.dart';
import 'package:my_app/features/children/data/child_requests.dart';
import 'package:my_app/features/children/data/children_repository.dart';
import 'package:my_app/features/children/data/interests_repository.dart';
import 'package:my_app/features/children/data/models/child.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

void main() {
  late TestApi api;

  setUp(
    () => api = TestApi.create(
      token: 'tok',
      locale: 'ar',
      activeFamilyId: 'family-1',
    ),
  );
  tearDown(() => api.dispose());

  ChildrenRepository children() =>
      api.container.read(childrenRepositoryProvider);
  InterestsRepository interests() =>
      api.container.read(interestsRepositoryProvider);

  group('interests', () {
    test('parses the plain (no-meta) localized catalog, ordered', () async {
      api.adapter.onGet(
        '/interests',
        (s) => s.reply(200, Fixtures.interestsEnvelope()),
      );

      final list = await interests().list();

      expect(list, hasLength(2));
      expect(list.first.id, 'int-animals');
      expect(list.first.name, 'الحيوانات');
      expect(list.map((i) => i.sortOrder), [1, 2]);
    });
  });

  group('children list', () {
    test('sends page / per_page / status and parses pagination meta', () async {
      api.adapter.onGet(
        '/families/family-1/children',
        (s) => s.reply(
          200,
          Fixtures.childrenPage(
            [Fixtures.childJson(id: 'c1'), Fixtures.childJson(id: 'c2')],
            currentPage: 1,
            lastPage: 3,
            total: 45,
          ),
        ),
      );

      final page = await children().list(familyId: 'family-1');

      expect(page.items.map((c) => c.id), ['c1', 'c2']);
      expect(page.meta.total, 45);
      expect(page.meta.hasMore, isTrue);
      final q = api.lastRequest.uri.queryParameters;
      expect(q['status'], 'active');
      expect(q['page'], '1');
      expect(q['per_page'], '20');
    });
  });

  group('create', () {
    test('POSTs birth_date + interest_ids and returns the new child', () async {
      Map<String, dynamic>? sentBody;
      api.adapter.onPost(
        '/families/family-1/children',
        (s) => s.reply(
          201,
          Fixtures.childEnvelope(child: Fixtures.childJson(id: 'new-1')),
        ),
        data: Matchers.any,
      );

      final child = await children().create(
        'family-1',
        ChildInput(
          name: 'Layan',
          birthDate: DateTime(2017, 5, 4),
          gender: ChildGender.female,
          interestIds: const ['int-animals'],
        ),
      );

      sentBody = api.lastRequest.data as Map<String, dynamic>;
      expect(child.id, 'new-1');
      expect(sentBody['birth_date'], '2017-05-04');
      expect(sentBody['interest_ids'], ['int-animals']);
      expect(sentBody['gender'], 'female');
      expect(
        sentBody.containsKey('age'),
        isFalse,
        reason: 'age is server-computed',
      );
    });

    test(
      'surfaces a 422 as a validation ApiException with field errors',
      () async {
        api.adapter.onPost(
          '/families/family-1/children',
          (s) => s.reply(
            422,
            Fixtures.validationError(
              errors: {
                'birth_date': [
                  'The birth date must be a date before or equal to today.',
                ],
              },
            ),
          ),
          data: Matchers.any,
        );

        final err = await _capture(
          () => children().create(
            'family-1',
            ChildInput(name: 'X', birthDate: DateTime(2999, 1, 1)),
          ),
        );
        expect(err.kind, ApiErrorKind.validation);
        expect(
          err.fieldError('birth_date'),
          contains('before or equal to today'),
        );
      },
    );
  });

  test('update issues a PATCH', () async {
    api.adapter.onPatch(
      '/families/family-1/children/child-1',
      (s) => s.reply(
        200,
        Fixtures.childEnvelope(child: Fixtures.childJson(name: 'Renamed')),
      ),
      data: Matchers.any,
    );

    final child = await children().update(
      'family-1',
      'child-1',
      ChildInput(name: 'Renamed', birthDate: DateTime(2017, 5, 4)),
    );
    expect(child.name, 'Renamed');
    expect(api.lastRequest.method, 'PATCH');
  });

  test(
    'delete issues a DELETE and completes on a null-data envelope',
    () async {
      api.adapter.onDelete(
        '/families/family-1/children/child-1',
        (s) => s.reply(
          200,
          Fixtures.messageEnvelope('Child profile deleted successfully.'),
        ),
      );

      await children().delete('family-1', 'child-1');
      expect(api.lastRequest.method, 'DELETE');
    },
  );

  test('caregiver create → 403 forbidden', () async {
    api.adapter.onPost(
      '/families/family-1/children',
      (s) => s.reply(403, {
        'success': false,
        'message': 'This action is unauthorized.',
      }),
      data: Matchers.any,
    );
    final err = await _capture(
      () => children().create(
        'family-1',
        ChildInput(name: 'X', birthDate: DateTime(2018, 1, 1)),
      ),
    );
    expect(err.kind, ApiErrorKind.forbidden);
  });

  test('cross-family / unknown child → 404 notFound', () async {
    api.adapter.onGet(
      '/families/family-1/children/ghost',
      (s) => s.reply(404, {'success': false, 'message': 'Resource not found.'}),
    );
    final err = await _capture(() => children().show('family-1', 'ghost'));
    expect(err.kind, ApiErrorKind.notFound);
  });
}

Future<ApiException> _capture(Future<void> Function() action) async {
  try {
    await action();
    fail('expected an ApiException');
  } on ApiException catch (e) {
    return e;
  }
}
