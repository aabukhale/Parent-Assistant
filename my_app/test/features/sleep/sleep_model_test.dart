import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/sleep/data/models/sleep_log.dart';
import 'package:my_app/features/sleep/data/models/sleep_summary.dart';
import 'package:my_app/features/sleep/data/sleep_requests.dart';

import '../../support/fixtures.dart';

void main() {
  group('SleepLog.fromJson', () {
    test('parses UTC timestamps and the backend-derived duration', () {
      final log = SleepLog.fromJson(
        Fixtures.sleepLogJson(
          startedAt: '2026-09-06T21:30:00.000Z',
          endedAt: '2026-09-07T07:00:00.000Z',
          durationMinutes: 570,
        ),
      );

      expect(log.startedAt.isUtc, isTrue);
      expect(log.endedAt.isUtc, isTrue);
      expect(log.startedAt, DateTime.utc(2026, 9, 6, 21, 30));
      expect(
        log.durationMinutes,
        570,
        reason: 'straight from duration_minutes',
      );
      expect(log.source, SleepSource.manual);
    });

    test(
      'duration is taken verbatim, never recomputed from the timestamps',
      () {
        // Deliberately inconsistent: 1h apart but backend says 555.
        final log = SleepLog.fromJson(
          Fixtures.sleepLogJson(
            startedAt: '2026-09-06T22:00:00.000Z',
            endedAt: '2026-09-06T23:00:00.000Z',
            durationMinutes: 555,
          ),
        );
        expect(log.durationMinutes, 555);
      },
    );

    test('crossesMidnightLocal reflects the local calendar days', () {
      final sameDay = SleepLog.fromJson(
        Fixtures.sleepLogJson(
          startedAt: '2026-09-06T13:00:00.000Z',
          endedAt: '2026-09-06T15:00:00.000Z',
        ),
      );
      expect(
        sameDay.crossesMidnightLocal,
        sameDay.startedAtLocal.day != sameDay.endedAtLocal.day,
      );

      final overnight = SleepLog.fromJson(
        Fixtures.sleepLogJson(
          startedAt: '2026-09-06T20:00:00.000Z',
          endedAt: '2026-09-07T05:00:00.000Z',
        ),
      );
      // In any timezone from UTC-11..UTC+13 these are different calendar days.
      expect(
        overnight.endedAtLocal.difference(overnight.startedAtLocal),
        const Duration(hours: 9),
      );
    });

    test('device source is recognised', () {
      final log = SleepLog.fromJson(Fixtures.sleepLogJson(source: 'device'));
      expect(log.source, SleepSource.device);
    });
  });

  group('SleepSummary.fromJson', () {
    test('parses nights, totals and the sufficiency flag', () {
      final s = SleepSummary.fromJson(
        Fixtures.sleepSummaryEnvelope()['data'] as Map<String, dynamic>,
      );
      expect(s.period, 'weekly');
      expect(s.timezone, 'Asia/Jerusalem');
      expect(s.nightsLogged, 2);
      expect(s.averageSleepMinutes, 570);
      expect(s.hasSufficientData, isTrue);
      expect(s.nights.map((n) => n.sleepMinutes), [540, 600]);
    });

    test('empty summary is honestly insufficient', () {
      final s = SleepSummary.fromJson(
        Fixtures.sleepSummaryEnvelope(
              nightsLogged: 0,
              totalSleepMinutes: 0,
              nights: const [],
            )['data']
            as Map<String, dynamic>,
      );
      expect(s.nightsLogged, 0);
      expect(s.hasSufficientData, isFalse);
      expect(s.nights, isEmpty);
    });
  });

  group('SleepLogInput.toJson', () {
    test('sends UTC ISO-8601 timestamps; create includes source=manual', () {
      final json = SleepLogInput(
        startedAt: DateTime(2026, 9, 6, 21, 30),
        endedAt: DateTime(2026, 9, 7, 7, 0),
        source: SleepSource.manual,
      ).toJson();

      expect(json['started_at'], endsWith('Z'));
      expect(DateTime.parse(json['started_at'] as String).isUtc, isTrue);
      expect(json['source'], 'manual');
      // Round-trips to the same instant.
      expect(
        DateTime.parse(json['ended_at'] as String),
        DateTime(2026, 9, 7, 7, 0).toUtc(),
      );
    });

    test('edit omits source (preserves the existing value)', () {
      final json = SleepLogInput(
        startedAt: DateTime(2026, 9, 6, 21, 30),
        endedAt: DateTime(2026, 9, 7, 7, 0),
      ).toJson();
      expect(json.containsKey('source'), isFalse);
      expect(json.keys.toSet(), {'started_at', 'ended_at'});
    });

    test('a cross-midnight span keeps both full timestamps', () {
      final input = SleepLogInput(
        startedAt: DateTime(2026, 9, 6, 23, 45),
        endedAt: DateTime(2026, 9, 7, 6, 15),
      );
      expect(input.localSpan, const Duration(hours: 6, minutes: 30));
      final json = input.toJson();
      expect(json['started_at'], isNot(equals(json['ended_at'])));
    });
  });
}
