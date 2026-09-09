import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/features/children/application/children_controller.dart';
import 'package:my_app/features/children/application/selected_child_controller.dart';
import 'package:my_app/features/children/data/child_requests.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

void main() {
  late TestApi api;

  setUp(() => api = TestApi.create(token: 'tok', activeFamilyId: 'family-1'));
  tearDown(() => api.dispose());

  Future<ChildrenListState> settle() async {
    for (var i = 0; i < 60; i++) {
      final s = api.container.read(childrenControllerProvider);
      if (s.hasValue && !s.isLoading) return s.requireValue;
      await Future<void>.delayed(Duration.zero);
    }
    return api.container.read(childrenControllerProvider).requireValue;
  }

  test('loads page 1 of children for the active family', () async {
    api.adapter.onGet(
      '/families/family-1/children',
      (s) => s.reply(
        200,
        Fixtures.childrenPage([
          Fixtures.childJson(id: 'c1', name: 'Layan'),
          Fixtures.childJson(id: 'c2'),
        ]),
      ),
    );

    final state = await settle();
    expect(state.children.map((c) => c.id), ['c1', 'c2']);
    expect(state.statusFilter, 'active');
  });

  test(
    'switching family reloads and drops the previous family\'s rows',
    () async {
      api.adapter
        ..onGet(
          '/families/family-1/children',
          (s) => s.reply(
            200,
            Fixtures.childrenPage([Fixtures.childJson(id: 'a1')]),
          ),
        )
        ..onGet(
          '/families/family-2/children',
          (s) => s.reply(
            200,
            Fixtures.childrenPage([
              Fixtures.childJson(id: 'b1', familyId: 'family-2'),
            ]),
          ),
        );

      await settle();
      expect((await settle()).children.single.id, 'a1');

      api.setActiveFamily('family-2');
      final after = await settle();
      expect(after.children.single.id, 'b1');
    },
  );

  test('loadMore appends the next page', () async {
    api.adapter.onGet(
      '/families/family-1/children',
      (s) => s.reply(
        200,
        Fixtures.childrenPage(
          [Fixtures.childJson(id: 'p1a'), Fixtures.childJson(id: 'p1b')],
          currentPage: 1,
          lastPage: 2,
          total: 3,
        ),
      ),
    );
    await settle();

    // Second page for the follow-up request.
    api.adapter.onGet(
      '/families/family-1/children',
      (s) => s.reply(
        200,
        Fixtures.childrenPage(
          [Fixtures.childJson(id: 'p2a')],
          currentPage: 2,
          lastPage: 2,
          total: 3,
        ),
      ),
    );

    await api.container.read(childrenControllerProvider.notifier).loadMore();
    final state = api.container.read(childrenControllerProvider).requireValue;

    expect(state.children.map((c) => c.id), ['p1a', 'p1b', 'p2a']);
    expect(state.hasMore, isFalse);
  });

  test('setStatusFilter refetches with the new status', () async {
    api.adapter.onGet(
      '/families/family-1/children',
      (s) => s.reply(
        200,
        Fixtures.childrenPage([Fixtures.childJson(id: 'active-1')]),
      ),
    );
    await settle();

    api.adapter.onGet(
      '/families/family-1/children',
      (s) => s.reply(
        200,
        Fixtures.childrenPage([
          Fixtures.childJson(id: 'arch-1', status: 'archived'),
        ]),
      ),
    );
    await api.container
        .read(childrenControllerProvider.notifier)
        .setStatusFilter('archived');
    await settle();

    final state = api.container.read(childrenControllerProvider).requireValue;
    expect(state.statusFilter, 'archived');
    expect(state.children.single.id, 'arch-1');
    expect(api.lastRequest.uri.queryParameters['status'], 'archived');
  });

  test('createChild posts then refreshes the list', () async {
    api.adapter.onGet(
      '/families/family-1/children',
      (s) => s.reply(
        200,
        Fixtures.childrenPage([Fixtures.childJson(id: 'existing')]),
      ),
    );
    await settle();

    api.adapter
      ..onPost(
        '/families/family-1/children',
        (s) => s.reply(
          201,
          Fixtures.childEnvelope(child: Fixtures.childJson(id: 'created')),
        ),
        data: Matchers.any,
      )
      ..onGet(
        '/families/family-1/children',
        (s) => s.reply(
          200,
          Fixtures.childrenPage([
            Fixtures.childJson(id: 'created'),
            Fixtures.childJson(id: 'existing'),
          ]),
        ),
      );

    final child = await api.container
        .read(childrenControllerProvider.notifier)
        .createChild(ChildInput(name: 'New', birthDate: DateTime(2019, 3, 3)));

    expect(child.id, 'created');
    final state = api.container.read(childrenControllerProvider).requireValue;
    expect(state.children.map((c) => c.id), contains('created'));
  });

  test(
    'selected child auto-selects the first row and clears on delete',
    () async {
      api.adapter.onGet(
        '/families/family-1/children',
        (s) => s.reply(
          200,
          Fixtures.childrenPage([
            Fixtures.childJson(id: 'first'),
            Fixtures.childJson(id: 'second'),
          ]),
        ),
      );
      await settle();
      // allow the selected-child listener to run
      api.container.read(selectedChildIdProvider);
      await Future<void>.delayed(Duration.zero);

      expect(api.container.read(selectedChildIdProvider), 'first');

      api.container.read(selectedChildIdProvider.notifier).select('second');
      expect(api.container.read(selectedChildProvider)?.id, 'second');

      api.adapter
        ..onDelete(
          '/families/family-1/children/second',
          (s) => s.reply(200, Fixtures.messageEnvelope('deleted')),
        )
        ..onGet(
          '/families/family-1/children',
          (s) => s.reply(
            200,
            Fixtures.childrenPage([Fixtures.childJson(id: 'first')]),
          ),
        );

      await api.container
          .read(childrenControllerProvider.notifier)
          .deleteChild('second');
      await Future<void>.delayed(Duration.zero);

      // 'second' is gone; the listener re-points the selection at the surviving row.
      expect(api.container.read(selectedChildIdProvider), 'first');
    },
  );

  test('switching family clears the selected child', () async {
    api.adapter
      ..onGet(
        '/families/family-1/children',
        (s) => s.reply(
          200,
          Fixtures.childrenPage([Fixtures.childJson(id: 'f1-child')]),
        ),
      )
      ..onGet(
        '/families/family-2/children',
        (s) => s.reply(200, Fixtures.childrenPage([])),
      );

    await settle();
    api.container.read(selectedChildIdProvider);
    await Future<void>.delayed(Duration.zero);
    expect(api.container.read(selectedChildIdProvider), 'f1-child');

    api.setActiveFamily('family-2');
    await settle();
    await Future<void>.delayed(Duration.zero);

    expect(api.container.read(selectedChildIdProvider), isNull);
  });
}
