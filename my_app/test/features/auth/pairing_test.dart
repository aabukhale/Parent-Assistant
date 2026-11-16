import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/core/errors/api_exception.dart';
import 'package:my_app/features/auth/data/child_auth_repository.dart';

import '../../support/test_api.dart';

void main() {
  group('pairing codes', () {
    test('normalizes what a child might type', () {
      expect(normalizePairingCode('dzqn-9n6k'), 'DZQN9N6K');
      expect(normalizePairingCode(' DZQN 9N6K '), 'DZQN9N6K');
      expect(normalizePairingCode('DZQN_9N6K'), 'DZQN9N6K');
    });

    test('rejects wrong length and look-alike characters', () {
      expect(normalizePairingCode('DZQN9N6'), isNull);
      expect(normalizePairingCode('DZQN9N6KX'), isNull);
      expect(normalizePairingCode('DZQN0N6K'), isNull, reason: '0 vs O');
      expect(normalizePairingCode('DZQN1N6K'), isNull, reason: '1 vs I');
    });

    test('reads the code from a mamily://pair link or plain text', () {
      expect(pairingCodeFromLink('mamily://pair?code=DZQN-9N6K'), 'DZQN9N6K');
      expect(pairingCodeFromLink('DZQN-9N6K'), 'DZQN9N6K');
      expect(pairingCodeFromLink('mamily://pair'), isNull);
      expect(pairingCodeFromLink('https://evil.example/?code=DZQN9N6K'), null);
    });

    test('a code with something glued on after it still pairs', () {
      // E.g. a QR that encoded the link followed by the formatted code and
      // expiry ("…?code=689RDY9T 689R-DY9T 2026-11-16T20:08:15Z").
      for (final link in [
        'mamily://pair?code=4VPBY39C?source=camera&x=1',
        'mamily://pair?code=4VPB-Y39C/extra',
        'mamily://pair?code=4vpby39c%20trailing',
        'mamily://pair?code=4VPBY39C 4VPB-Y39C 2026-11-16T20:08:15.000000Z',
      ]) {
        expect(pairingCodeFromLink(link), '4VPBY39C', reason: link);
      }
      // Never a code fished out of other text, or a longer token.
      for (final link in [
        'mamily://pair?code=xx4VPBY39C',
        'mamily://pair?code=4VPBY39CZZ',
        'mamily://pair?code=hello%204VPBY39C',
      ]) {
        expect(pairingCodeFromLink(link), isNull, reason: link);
      }
    });
  });

  group('ChildAuthRepository.pair', () {
    late TestApi api;
    setUp(() => api = TestApi.create(token: null, locale: 'en'));
    tearDown(() => api.dispose());

    test('redeems the normalized code and stores a child session', () async {
      final me =
          (jsonDecode(File('test/fixtures/kid/me.json').readAsStringSync())
              as Map<String, dynamic>)['data'];
      api.adapter.onPost(
        '/child-auth/pair',
        (s) => s.reply(201, {
          'success': true,
          'data': {'token': 'child-tok', 'token_type': 'Bearer', 'session': me},
        }),
        data: Matchers.any,
      );

      final session = await api.container
          .read(childAuthRepositoryProvider)
          .pair('dzqn-9n6k', deviceName: 'Test phone');

      final body =
          api.requests
                  .singleWhere((r) => r.path.endsWith('/child-auth/pair'))
                  .data
              as Map;
      expect(body['code'], 'DZQN9N6K');
      expect(
        (body['install_id_hash'] as String).length,
        greaterThanOrEqualTo(16),
      );
      expect(session.name, 'Omar');
      expect(await api.storage.readToken(), 'child-tok');
      expect(await api.storage.readSessionKind(), 'child');
    });

    test('an invalid code never reaches the server', () async {
      await expectLater(
        api.container
            .read(childAuthRepositoryProvider)
            .pair('nope', deviceName: 'Test phone'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.validation,
          ),
        ),
      );
      expect(
        api.requests.where((r) => r.path.endsWith('/child-auth/pair')),
        isEmpty,
      );
      expect(await api.storage.readToken(), isNull);
    });
  });
}
