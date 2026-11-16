import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/features/remote/data/remote_repository.dart';

import '../../support/test_api.dart';

Map<String, dynamic> _ok(Object? data) => {'success': true, 'data': data};

Map<String, dynamic> _session({
  String kind = 'voice_call',
  String status = 'requested',
  String? endReason,
}) => {
  'id': 'rs1',
  'kind': kind,
  'initiated_by': 'parent',
  'status': status,
  'end_reason': endReason,
  'can_accept': status == 'requested',
  'scope': kind == 'video_call' ? 'audio_video' : 'audio',
  'child_id': 'child-1',
  'child_name': 'Omar',
  'adult': {'id': 'u1', 'name': 'Dana'},
  'request_expires_at': '2026-10-22T22:30:00Z',
};

Map<dynamic, dynamic> _sent(TestApi api, String path) =>
    api.requests.lastWhere((r) => r.path.endsWith(path)).data as Map;

void main() {
  group('models', () {
    test('session flags follow kind and status', () {
      final s = RemoteSession.fromJson(_session(kind: 'video_call'));
      expect(s.isRequested, isTrue);
      expect(s.isLive, isTrue);
      expect(s.isCall, isTrue);
      expect(s.isVideo, isTrue);
      expect(s.canAccept, isTrue);
      expect(s.adultName, 'Dana');
      expect(s.scope, 'audio_video');

      final ended = RemoteSession.fromJson(
        _session(status: 'ended', endReason: 'idle'),
      );
      expect(ended.isLive, isFalse);
      expect(ended.endReason, 'idle');

      final help = RemoteSession.fromJson(_session(kind: 'in_app_help'));
      expect(help.isCall, isFalse);
    });

    test('signal payload keeps SDP text exactly', () {
      const sdp = 'v=0\r\no=- 1 2 IN IP4 127.0.0.1\r\na=mid:0\r\n';
      final s = RemoteSignal.fromJson(const {
        'id': 7,
        'type': 'offer',
        'payload': {'sdp': sdp, 'type': 'offer'},
      });
      expect(s.id, 7);
      expect(s.payload['sdp'], sdp);
    });
  });

  group('child side', () {
    late TestApi api;
    late RemoteRepository repo;
    setUp(() {
      api = TestApi.create(token: 'child-token');
      repo = api.container.read(kidRemoteRepositoryProvider);
    });
    tearDown(() => api.dispose());

    test('live: null when nothing is waiting', () async {
      api.adapter.onGet(
        '/child/remote-sessions/live',
        (s) => s.reply(200, _ok(null)),
      );
      expect(await repo.live(), isNull);
    });

    test('live: an incoming call the child can accept', () async {
      api.adapter.onGet(
        '/child/remote-sessions/live',
        (s) => s.reply(200, _ok(_session())),
      );
      final s = await repo.live();
      expect(s!.canAccept, isTrue);
      expect(s.isCall, isTrue);
    });

    test('a child asks a specific adult', () async {
      api.adapter.onPost(
        '/child/remote-sessions',
        (s) => s.reply(201, _ok(_session())),
        data: Matchers.any,
      );
      await repo.request('voice_call', adultId: 'u1');
      final body = _sent(api, '/child/remote-sessions');
      expect(body['kind'], 'voice_call');
      expect(body['user_id'], 'u1');
    });

    test('poll: session state plus signals after the cursor', () async {
      api.adapter.onGet(
        '/child/remote-sessions/rs1/signals',
        (s) => s.reply(
          200,
          _ok({
            'session': _session(status: 'active'),
            'signals': [
              {
                'id': 3,
                'type': 'ice',
                'payload': {
                  'candidate': 'candidate:1 1 udp 1 10.0.0.1 5000 typ host',
                  'sdpMid': '0',
                  'sdpMLineIndex': 0,
                },
              },
            ],
          }),
        ),
        queryParameters: {'after': 2},
      );
      final r = await repo.poll('rs1', 2);
      expect(r.session.isActive, isTrue);
      expect(r.signals.single.id, 3);
      expect(r.signals.single.payload['sdpMLineIndex'], 0);
    });

    test('ending reports who ended it', () async {
      api.adapter.onPost(
        '/child/remote-sessions/rs1/end',
        (s) => s.reply(
          200,
          _ok(_session(status: 'ended', endReason: 'child_ended')),
        ),
      );
      final s = await repo.end('rs1');
      expect(s.endReason, 'child_ended');
      expect(s.isLive, isFalse);
    });

    test('ICE config says when no relay is configured', () async {
      api.adapter.onGet(
        '/child/remote-sessions/rs1/ice',
        (s) => s.reply(
          200,
          _ok({
            'ice_servers': [
              {
                'urls': ['stun:stun.l.google.com:19302'],
              },
            ],
            'relay_configured': false,
          }),
        ),
      );
      final ice = await repo.ice('rs1');
      expect(ice.relayConfigured, isFalse);
      expect(ice.servers.single['urls'], isNotEmpty);
    });

    test('signals are sent with their payload untouched', () async {
      api.adapter.onPost(
        '/child/remote-sessions/rs1/signals',
        (s) => s.reply(201, _ok({'id': 9})),
        data: Matchers.any,
      );
      const sdp = 'v=0\r\na=mid:0\r\n';
      await repo.signal('rs1', 'answer', {'sdp': sdp, 'type': 'answer'});
      final body = _sent(api, '/rs1/signals');
      expect(body['type'], 'answer');
      expect((body['payload'] as Map)['sdp'], sdp);
    });
  });

  group('parent side', () {
    late TestApi api;
    late RemoteRepository repo;
    setUp(() {
      api = TestApi.create(token: 'tok', activeFamilyId: 'family-1');
      repo = api.container.read(parentRemoteRepositoryProvider);
    });
    tearDown(() => api.dispose());

    test('never polls the child-only live endpoint', () async {
      expect(await repo.live(), isNull);
      expect(api.requests.where((r) => r.path.contains('/live')), isEmpty);
    });

    test('asks a child through the child route', () async {
      api.adapter.onPost(
        '/families/family-1/children/child-1/remote-sessions',
        (s) => s.reply(201, _ok(_session(kind: 'in_app_help'))),
        data: Matchers.any,
      );
      final s = await repo.request(
        'in_app_help',
        childId: 'child-1',
        familyId: 'family-1',
      );
      expect(
        _sent(api, '/children/child-1/remote-sessions')['kind'],
        'in_app_help',
      );
      expect(s.isRequested, isTrue);
    });

    test('frame: none yet vs a snapshot with its time', () async {
      api.adapter.onGet(
        '/families/family-1/remote-sessions/rs1/frame',
        (s) => s.reply(
          200,
          _ok({
            'session': _session(kind: 'in_app_help', status: 'active'),
            'frame': {'data': 'aGVsbG8=', 'at': '2026-10-22T19:08:40Z'},
          }),
        ),
      );
      final f = await repo.frame('rs1');
      expect(f.frame, 'aGVsbG8=');
      expect(f.at, isNotNull);
    });
  });
}
