import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/core/errors/api_exception.dart';
import 'package:my_app/features/content_control/application/content_controller.dart';
import 'package:my_app/features/content_control/data/content_repository.dart';
import 'package:my_app/features/content_control/data/content_requests.dart';
import 'package:my_app/features/content_control/data/models/content_enums.dart';
import 'package:my_app/features/content_control/data/models/content_item.dart';
import 'package:my_app/features/content_control/presentation/content_control_screen.dart';
import 'package:my_app/l10n/app_localizations.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

void main() {
  const c = '/families/family-1/children/child-1';

  group('models', () {
    test(
      'EffectiveContentPolicy: decision maps + channels + nullable ages',
      () {
        final p = EffectiveContentPolicy.fromJson(
          Fixtures.contentPolicyEnvelope(
                childAge: null,
                ageFilterEnabled: false,
                categoryDecisions: {'cat-1': 'block'},
                itemDecisions: {'item-9': 'allow'},
                externalChannels: [
                  {
                    'provider_key': 'youtube',
                    'external_ref': 'UCx',
                    'label': 'X',
                    'decision': 'block',
                  },
                ],
              )['data']
              as Map<String, dynamic>,
        );
        expect(p.ageFilterEnabled, isFalse);
        expect(p.childAge, isNull);
        expect(p.categoryDecisions['cat-1'], ContentDecision.block);
        expect(p.itemDecisions['item-9'], ContentDecision.allow);
        expect(p.externalChannels.single.decision, ContentDecision.block);
      },
    );

    test('ContentRule: unknown rule_type / decision tolerated', () {
      final r = ContentRule.fromJson(
        Fixtures.contentRuleJson(ruleType: 'new_kind', decision: 'maybe'),
      );
      expect(r.ruleType, ContentRuleType.unknown);
      expect(r.decision, ContentDecision.unknown);
    });

    test('ContentItem: unknown type tolerated; provider parsed', () {
      final i = ContentItem.fromJson(
        Fixtures.contentItemJson(type: 'hologram'),
      );
      expect(i.type, ContentType.unknown);
      expect(i.provider!.key, 'youtube');
    });

    test('ContentRuleInput: external channel body + idempotent shape', () {
      final json = const ContentRuleInput.externalChannel(
        decision: ContentDecision.block,
        providerKey: 'youtube',
        externalRef: 'UCabc',
        label: 'Bad channel',
      ).toJson();
      expect(json['rule_type'], 'external_channel');
      expect(json['decision'], 'block');
      expect(json['provider_key'], 'youtube');
      expect(json['external_ref'], 'UCabc');
    });
  });

  group('repository', () {
    late TestApi api;
    late ContentRepository repo;
    setUp(() {
      api = TestApi.create(
        token: 'tok',
        activeFamilyId: 'family-1',
        selectedChildId: 'child-1',
      );
      repo = api.container.read(contentRepositoryProvider);
    });
    tearDown(() => api.dispose());

    test('policy: GET child-scoped effective policy', () async {
      api.adapter.onGet(
        '$c/content-policy',
        (s) => s.reply(200, Fixtures.contentPolicyEnvelope()),
      );
      final p = await repo.policy('family-1', 'child-1');
      expect(p.childId, 'child-1');
    });

    test('setAgeFilter: PUT with age_filter_enabled', () async {
      api.adapter.onPut(
        '$c/content-policy',
        (s) => s.reply(
          200,
          Fixtures.contentPolicyEnvelope(ageFilterEnabled: false),
        ),
        data: Matchers.any,
      );
      final p = await repo.setAgeFilter('family-1', 'child-1', enabled: false);
      expect(p.ageFilterEnabled, isFalse);
      expect((api.lastRequest.data as Map)['age_filter_enabled'], isFalse);
    });

    test('saveRule: POST /content-rules (idempotent 200/201)', () async {
      api.adapter.onPost(
        '$c/content-rules',
        (s) => s.reply(201, Fixtures.contentRuleEnvelope()),
        data: Matchers.any,
      );
      final r = await repo.saveRule(
        'family-1',
        'child-1',
        const ContentRuleInput.externalChannel(
          decision: ContentDecision.block,
          providerKey: 'youtube',
          externalRef: 'UCabc',
        ),
      );
      expect(r.ruleType, ContentRuleType.externalChannel);
    });

    test('saveRule 422 for a category rule with no category', () async {
      api.adapter.onPost(
        '$c/content-rules',
        (s) => s.reply(
          422,
          Fixtures.validationError(
            errors: {
              'content_category_id': [
                'A category is required for category rules.',
              ],
            },
          ),
        ),
        data: Matchers.any,
      );
      try {
        await repo.saveRule(
          'family-1',
          'child-1',
          const ContentRuleInput.category(
            decision: ContentDecision.block,
            categoryId: '',
          ),
        );
        fail('expected');
      } on ApiException catch (e) {
        expect(e.kind, ApiErrorKind.validation);
      }
    });

    test('deleteRule: DELETE /content-rules/{id}', () async {
      api.adapter.onDelete(
        '$c/content-rules/r1',
        (s) => s.reply(200, Fixtures.messageEnvelope('removed')),
      );
      await repo.deleteRule('family-1', 'child-1', 'r1');
      expect(api.lastRequest.method, 'DELETE');
    });

    test('policy update without manage_content_policy → 403', () async {
      api.adapter.onPut(
        '$c/content-policy',
        (s) => s.reply(403, {
          'success': false,
          'message': 'This action is unauthorized.',
        }),
        data: Matchers.any,
      );
      try {
        await repo.setAgeFilter('family-1', 'child-1', enabled: true);
        fail('expected');
      } on ApiException catch (e) {
        expect(e.kind, ApiErrorKind.forbidden);
      }
    });
  });

  group('controller', () {
    test(
      'saveRule refreshes rules list AND re-reads effective policy',
      () async {
        final api = TestApi.create(
          token: 'tok',
          activeFamilyId: 'family-1',
          selectedChildId: 'child-1',
        );
        addTearDown(api.dispose);
        api.adapter
          ..onGet(
            '$c/content-rules',
            (s) => s.reply(200, Fixtures.contentRulesPage(const [])),
          )
          ..onGet(
            '$c/content-policy',
            (s) => s.reply(200, Fixtures.contentPolicyEnvelope()),
          );
        final rSub = api.container.listen(
          contentRulesControllerProvider,
          (_, _) {},
        );
        addTearDown(rSub.close);
        final pSub = api.container.listen(contentPolicyProvider, (_, _) {});
        addTearDown(pSub.close);
        await api.container.read(contentRulesControllerProvider.future);
        await api.container.read(contentPolicyProvider.future);

        api.adapter
          ..onPost(
            '$c/content-rules',
            (s) => s.reply(201, Fixtures.contentRuleEnvelope()),
            data: Matchers.any,
          )
          ..onGet(
            '$c/content-rules',
            (s) => s.reply(
              200,
              Fixtures.contentRulesPage([
                Fixtures.contentRuleJson(id: 'r-new'),
              ]),
            ),
          )
          ..onGet(
            '$c/content-policy',
            (s) => s.reply(
              200,
              Fixtures.contentPolicyEnvelope(
                externalChannels: [
                  {
                    'provider_key': 'youtube',
                    'external_ref': 'UCabc',
                    'label': null,
                    'decision': 'block',
                  },
                ],
              ),
            ),
          );

        await api.container
            .read(contentRulesControllerProvider.notifier)
            .saveRule(
              const ContentRuleInput.externalChannel(
                decision: ContentDecision.block,
                providerKey: 'youtube',
                externalRef: 'UCabc',
              ),
            );
        await Future<void>.delayed(Duration.zero);
        expect(
          api.container
              .read(contentRulesControllerProvider)
              .requireValue
              .rules
              .single
              .id,
          'r-new',
        );
        expect(
          (await api.container.read(
            contentPolicyProvider.future,
          )).externalChannels.single.decision,
          ContentDecision.block,
        );
      },
    );
  });

  group('widget', () {
    testWidgets('renders the age-filter tile + enforcement disclaimer', (
      tester,
    ) async {
      final l = lookupAppLocalizations(const Locale('en'));
      final api = TestApi.create(
        token: 'tok',
        locale: 'en',
        activeFamilyId: 'family-1',
        selectedChildId: 'child-1',
      );
      addTearDown(api.dispose);
      api.adapter
        ..onGet(
          '/families/family-1/members',
          (s) => s.reply(
            200,
            Fixtures.membersEnvelope([Fixtures.memberJson(role: 'owner')]),
          ),
        )
        ..onGet(
          '$c/content-policy',
          (s) => s.reply(200, Fixtures.contentPolicyEnvelope()),
        )
        ..onGet(
          '$c/content-rules',
          (s) => s.reply(
            200,
            Fixtures.contentRulesPage([
              Fixtures.contentRuleJson(label: 'Blocked channel'),
            ]),
          ),
        );
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: api.container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: ContentControlScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l.contentAgeFilter), findsOneWidget);
      expect(find.text(l.contentEnforcementNote), findsOneWidget);
      expect(find.text('Blocked channel'), findsOneWidget);
    });
  });
}
