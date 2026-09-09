import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/api/api_envelope.dart';
import 'package:my_app/features/rewards/data/models/reward.dart';
import 'package:my_app/features/rewards/data/models/reward_enums.dart';
import 'package:my_app/features/rewards/data/models/reward_redemption.dart';
import 'package:my_app/features/rewards/data/models/screen_time_override.dart';
import 'package:my_app/features/rewards/data/reward_requests.dart';

import '../../support/fixtures.dart';

void main() {
  group('Reward.fromJson', () {
    test('all reward types parse', () {
      for (final t in [
        'screen_time',
        'physical',
        'family_activity',
        'privilege',
      ]) {
        expect(
          Reward.fromJson(Fixtures.rewardJson(type: t)).type,
          RewardType.fromWire(t),
        );
      }
    });

    test('global vs family scope', () {
      final global = Reward.fromJson(Fixtures.rewardJson(familyId: null));
      expect(global.isGlobal, isTrue);
      expect(global.scope, 'global');
      final family = Reward.fromJson(Fixtures.rewardJson(familyId: 'family-1'));
      expect(family.isGlobal, isFalse);
      expect(family.scope, 'family');
    });

    test('screen_time reward exposes metadata.minutes only', () {
      final r = Reward.fromJson(
        Fixtures.rewardJson(
          type: 'screen_time',
          metadata: {'minutes': 30, 'ignored': 'x'},
        ),
      );
      expect(r.screenTimeMinutes, 30);
      final nonScreen = Reward.fromJson(
        Fixtures.rewardJson(type: 'physical', metadata: {'minutes': 30}),
      );
      expect(
        nonScreen.screenTimeMinutes,
        isNull,
        reason: 'minutes only meaningful for screen_time',
      );
    });

    test('tolerates null description / metadata', () {
      final r = Reward.fromJson(
        Fixtures.rewardJson(description: null, metadata: null),
      );
      expect(r.description, isNull);
      expect(r.metadata, isNull);
    });

    test('inactive flag', () {
      expect(
        Reward.fromJson(Fixtures.rewardJson(isActive: false)).isActive,
        isFalse,
      );
    });
  });

  group('RewardRedemption.fromJson', () {
    test('all statuses parse; snapshots are read from *_snapshot fields', () {
      for (final s in ['pending', 'approved', 'rejected', 'cancelled']) {
        final r = RewardRedemption.fromJson(Fixtures.redemptionJson(status: s));
        expect(r.status, RedemptionStatus.fromWire(s));
      }
      final r = RewardRedemption.fromJson(
        Fixtures.redemptionJson(
          rewardTitle: 'Old title',
          rewardType: 'privilege',
          pointsCost: 99,
        ),
      );
      expect(r.rewardTitle, 'Old title');
      expect(r.rewardType, RewardType.privilege);
      expect(r.pointsCost, 99);
    });

    test('action flags follow status', () {
      expect(
        RewardRedemption.fromJson(
          Fixtures.redemptionJson(status: 'pending'),
        ).canApproveOrReject,
        isTrue,
      );
      expect(
        RewardRedemption.fromJson(
          Fixtures.redemptionJson(status: 'approved'),
        ).canCancel,
        isTrue,
      );
      expect(
        RewardRedemption.fromJson(
          Fixtures.redemptionJson(status: 'approved'),
        ).canApproveOrReject,
        isFalse,
      );
      expect(
        RewardRedemption.fromJson(
          Fixtures.redemptionJson(status: 'cancelled'),
        ).canCancel,
        isFalse,
      );
      expect(
        RewardRedemption.fromJson(
          Fixtures.redemptionJson(status: 'rejected'),
        ).canApproveOrReject,
        isFalse,
      );
    });

    test(
      'screen_time_override: embedded object parses, absent/null → null',
      () {
        final withOverride = RewardRedemption.fromJson(
          Fixtures.redemptionJson(
            status: 'approved',
            rewardType: 'screen_time',
            deductionTxnId: 'txn-d',
            screenTimeOverride: Fixtures.screenTimeOverrideJson(
              additionalMinutes: 45,
            ),
          ),
        );
        expect(withOverride.screenTimeOverride, isNotNull);
        expect(withOverride.screenTimeOverride!.additionalMinutes, 45);
        expect(
          withOverride.screenTimeOverride!.source,
          ScreenTimeOverrideSource.rewardRedemption,
        );

        final without = RewardRedemption.fromJson(Fixtures.redemptionJson());
        expect(without.screenTimeOverride, isNull);

        final nullOverride = RewardRedemption.fromJson(
          Fixtures.redemptionJson()..['screen_time_override'] = null,
        );
        expect(nullOverride.screenTimeOverride, isNull);
      },
    );

    test('revoked override is flagged', () {
      final o = ScreenTimeOverride.fromJson(
        Fixtures.screenTimeOverrideJson(revokedAt: '2026-09-08T12:00:00.000Z'),
      );
      expect(o.isRevoked, isTrue);
      expect(o.isActive, isFalse);
    });

    test('deduction / refund transaction ids surface', () {
      final approved = RewardRedemption.fromJson(
        Fixtures.redemptionJson(status: 'approved', deductionTxnId: 'd1'),
      );
      expect(approved.deductionTransactionId, 'd1');
      final cancelled = RewardRedemption.fromJson(
        Fixtures.redemptionJson(
          status: 'cancelled',
          deductionTxnId: 'd1',
          refundTxnId: 'r1',
        ),
      );
      expect(cancelled.refundTransactionId, 'r1');
    });
  });

  group('request payloads', () {
    test(
      'RewardCreateInput: screen_time sends metadata.minutes; others do not',
      () {
        final st = RewardCreateInput(
          title: 'X',
          type: RewardType.screenTime,
          pointsCost: 100,
          screenTimeMinutes: 30,
        ).toJson();
        expect(st['metadata'], {'minutes': 30});
        expect(st['type'], 'screen_time');

        final physical = RewardCreateInput(
          title: 'X',
          type: RewardType.physical,
          pointsCost: 100,
          screenTimeMinutes: 30,
        ).toJson();
        expect(physical.containsKey('metadata'), isFalse);
      },
    );

    test(
      'RewardUpdateInput never sends type; clear flag sends explicit null',
      () {
        final json = const RewardUpdateInput(
          title: 'New',
          clearDescription: true,
          pointsCost: 20,
          isActive: false,
        ).toJson();
        expect(json.containsKey('type'), isFalse);
        expect(json['description'], isNull);
        expect(json['points_cost'], 20);
        expect(json['is_active'], isFalse);
      },
    );

    test(
      'RewardUpdateInput.fromReward sends metadata only for screen_time',
      () {
        final screenReward = Reward.fromJson(
          Fixtures.rewardJson(type: 'screen_time', metadata: {'minutes': 10}),
        );
        final json = RewardUpdateInput.fromReward(
          screenReward,
          title: 'T',
          description: null,
          pointsCost: 5,
          isActive: true,
          screenTimeMinutes: 40,
        ).toJson();
        expect(json['metadata'], {'minutes': 40});

        final physReward = Reward.fromJson(
          Fixtures.rewardJson(type: 'physical'),
        );
        final json2 = RewardUpdateInput.fromReward(
          physReward,
          title: 'T',
          description: null,
          pointsCost: 5,
          isActive: true,
          screenTimeMinutes: 40,
        ).toJson();
        expect(json2.containsKey('metadata'), isFalse);
      },
    );

    test('RedemptionRequestInput sends reward_id only', () {
      expect(const RedemptionRequestInput(rewardId: 'r-9').toJson(), {
        'reward_id': 'r-9',
      });
    });
  });

  test('Paginated.from parses reward + redemption pages', () {
    final rp = Paginated.from<Reward>(
      ApiEnvelope.fromJson(
        Fixtures.rewardsPage(
          [Fixtures.rewardJson(id: 'a'), Fixtures.rewardJson(id: 'b')],
          currentPage: 1,
          lastPage: 2,
          total: 5,
        ),
      ),
      Reward.fromJson,
    );
    expect(rp.items.map((r) => r.id), ['a', 'b']);
    expect(rp.meta.hasMore, isTrue);

    final dp = Paginated.from<RewardRedemption>(
      ApiEnvelope.fromJson(
        Fixtures.redemptionsPage([Fixtures.redemptionJson(id: 'x')]),
      ),
      RewardRedemption.fromJson,
    );
    expect(dp.items.single.id, 'x');
  });
}
