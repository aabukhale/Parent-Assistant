import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';

DateTime? _date(Object? v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v)?.toLocal() : null;

/// A consent-based remote session between one adult and one child.
class RemoteSession {
  const RemoteSession({
    required this.id,
    required this.kind,
    required this.initiatedBy,
    required this.status,
    required this.canAccept,
    required this.scope,
    this.endReason,
    this.childId,
    this.childName,
    this.adultId,
    this.adultName,
    this.requestExpiresAt,
    this.acceptedAt,
    this.endsBy,
  });

  final String id;

  /// in_app_help | screen_share | voice_call | video_call
  final String kind;

  /// parent | child
  final String initiatedBy;

  /// requested | active | declined | ended | expired
  final String status;
  final String? endReason;
  final bool canAccept;

  /// mamily_screen_view_and_pointer | device_screen_view_only | audio |
  /// audio_video — what the session really allows.
  final String scope;
  final String? childId;
  final String? childName;
  final String? adultId;
  final String? adultName;
  final DateTime? requestExpiresAt;
  final DateTime? acceptedAt;
  final DateTime? endsBy;

  bool get isRequested => status == 'requested';
  bool get isActive => status == 'active';
  bool get isLive => isRequested || isActive;
  bool get isCall => kind == 'voice_call' || kind == 'video_call';
  bool get isVideo => kind == 'video_call';

  factory RemoteSession.fromJson(Map<String, dynamic> j) {
    final adult = (j['adult'] as Map?)?.cast<String, dynamic>();
    return RemoteSession(
      id: j['id'] as String,
      kind: j['kind'] as String? ?? 'in_app_help',
      initiatedBy: j['initiated_by'] as String? ?? 'parent',
      status: j['status'] as String? ?? 'requested',
      endReason: j['end_reason'] as String?,
      canAccept: j['can_accept'] as bool? ?? false,
      scope: j['scope'] as String? ?? '',
      childId: j['child_id'] as String?,
      childName: j['child_name'] as String?,
      adultId: adult?['id'] as String?,
      adultName: adult?['name'] as String?,
      requestExpiresAt: _date(j['request_expires_at']),
      acceptedAt: _date(j['accepted_at']),
      endsBy: _date(j['ends_by']),
    );
  }
}

class RemoteSignal {
  const RemoteSignal({
    required this.id,
    required this.type,
    required this.payload,
  });

  final int id;

  /// offer | answer | ice | pointer | state
  final String type;
  final Map<String, dynamic> payload;

  factory RemoteSignal.fromJson(Map<String, dynamic> j) => RemoteSignal(
    id: (j['id'] as num).toInt(),
    type: j['type'] as String? ?? '',
    payload: (j['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
  );
}

typedef IceConfig = ({
  List<Map<String, dynamic>> servers,
  bool relayConfigured,
});

/// One transport for both sides: the child uses `/child/remote-sessions/*`,
/// adults `/families/{f}/remote-sessions/*`. Same shapes either way.
class RemoteRepository {
  RemoteRepository(this._client, {required this.base});

  final ApiClient _client;

  /// `/child/remote-sessions` or `/families/{id}/remote-sessions`.
  final String base;

  bool get isChild => base.startsWith('/child');

  Future<RemoteSession?> live() async {
    if (!isChild) return null;
    final d = (await _client.get('$base/live')).data;
    return d is Map ? RemoteSession.fromJson(d.cast<String, dynamic>()) : null;
  }

  Future<List<RemoteSession>> recent() async {
    final d = (await _client.get(base)).data;
    return d is List
        ? d
              .whereType<Map>()
              .map((m) => RemoteSession.fromJson(m.cast<String, dynamic>()))
              .toList()
        : const [];
  }

  /// Adult: ask a child. Child: ask an adult ([adultId]).
  Future<RemoteSession> request(
    String kind, {
    String? childId,
    String? familyId,
    String? adultId,
  }) async {
    final env = isChild
        ? await _client.post(base, body: {'kind': kind, 'user_id': adultId})
        : await _client.post(
            '/families/$familyId/children/$childId/remote-sessions',
            body: {'kind': kind},
          );
    return RemoteSession.fromJson(env.dataMap);
  }

  Future<RemoteSession> show(String id) async =>
      RemoteSession.fromJson((await _client.get('$base/$id')).dataMap);

  Future<RemoteSession> accept(String id) async =>
      RemoteSession.fromJson((await _client.post('$base/$id/accept')).dataMap);

  Future<RemoteSession> decline(String id) async =>
      RemoteSession.fromJson((await _client.post('$base/$id/decline')).dataMap);

  Future<RemoteSession> end(String id) async =>
      RemoteSession.fromJson((await _client.post('$base/$id/end')).dataMap);

  Future<({RemoteSession session, List<RemoteSignal> signals})> poll(
    String id,
    int after,
  ) async {
    final d = (await _client.get(
      '$base/$id/signals',
      query: {'after': after},
    )).dataMap;
    return (
      session: RemoteSession.fromJson(
        (d['session'] as Map).cast<String, dynamic>(),
      ),
      signals: ((d['signals'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => RemoteSignal.fromJson(m.cast<String, dynamic>()))
          .toList(),
    );
  }

  Future<void> signal(String id, String type, Map<String, dynamic> payload) =>
      _client.post(
        '$base/$id/signals',
        body: {'type': type, 'payload': payload},
      );

  /// Child only: latest snapshot of the Mamily screen (base64 PNG/JPEG).
  Future<void> putFrame(String id, String base64Image) =>
      _client.post('$base/$id/frame', body: {'image': base64Image});

  /// Adult only.
  Future<({RemoteSession session, String? frame, DateTime? at})> frame(
    String id,
  ) async {
    final d = (await _client.get('$base/$id/frame')).dataMap;
    final f = d['frame'] as Map?;
    return (
      session: RemoteSession.fromJson(
        (d['session'] as Map).cast<String, dynamic>(),
      ),
      frame: f?['data'] as String?,
      at: _date(f?['at']),
    );
  }

  Future<IceConfig> ice(String id) async {
    final d = (await _client.get('$base/$id/ice')).dataMap;
    return (
      servers: ((d['ice_servers'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList(),
      relayConfigured: d['relay_configured'] as bool? ?? false,
    );
  }
}

final kidRemoteRepositoryProvider = Provider<RemoteRepository>(
  (ref) => RemoteRepository(
    ref.watch(apiClientProvider),
    base: '/child/remote-sessions',
  ),
);

final parentRemoteRepositoryProvider = Provider<RemoteRepository>(
  (ref) => RemoteRepository(
    ref.watch(apiClientProvider),
    base:
        '/families/${ref.watch(activeFamilyIdProvider) ?? ''}/remote-sessions',
  ),
);
