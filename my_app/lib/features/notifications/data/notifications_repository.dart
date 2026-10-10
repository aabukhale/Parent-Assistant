import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import 'notification_models.dart';

/// Inbox for whoever is signed in: `/notifications` for adults,
/// `/child/notifications` for a paired child. The server decides the recipient
/// from the token.
class NotificationsRepository {
  NotificationsRepository(this._client, {required this.isChild});

  final ApiClient _client;
  final bool isChild;

  String get _base => isChild ? '/child/notifications' : '/notifications';

  Future<({List<AppNotification> items, bool hasMore})> page({
    int page = 1,
    bool unreadOnly = false,
  }) async {
    final env = await _client.get(
      _base,
      query: {'page': page, 'per_page': 20, if (unreadOnly) 'unread': 1},
    );
    final items = env.dataList
        .whereType<Map>()
        .map((m) => AppNotification.fromJson(m.cast<String, dynamic>()))
        .toList();
    final meta = env.meta;
    final current = (meta?['current_page'] as num?)?.toInt() ?? page;
    final last = (meta?['last_page'] as num?)?.toInt() ?? page;
    return (items: items, hasMore: current < last);
  }

  Future<int> unreadCount() async {
    final env = await _client.get('$_base/unread-count');
    return (env.dataMap['unread'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(String id) => _client.post('$_base/$id/read');

  Future<void> markAllRead() => _client.post('$_base/read-all');
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  final isChild = ref.watch(authControllerProvider.select((s) => s.isChild));
  return NotificationsRepository(
    ref.watch(apiClientProvider),
    isChild: isChild,
  );
});
