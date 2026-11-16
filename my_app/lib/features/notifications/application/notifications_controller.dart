import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_models.dart';
import '../data/notifications_repository.dart';

class InboxState {
  const InboxState({
    required this.items,
    required this.hasMore,
    this.page = 1,
    this.loadingMore = false,
  });

  final List<AppNotification> items;
  final bool hasMore;
  final int page;
  final bool loadingMore;

  int get unread => items.where((n) => !n.isRead).length;

  InboxState copyWith({
    List<AppNotification>? items,
    bool? hasMore,
    int? page,
    bool? loadingMore,
  }) => InboxState(
    items: items ?? this.items,
    hasMore: hasMore ?? this.hasMore,
    page: page ?? this.page,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// Paginated, durable inbox (server state). Mark-read is applied locally after
/// the server confirms.
class InboxController extends AutoDisposeAsyncNotifier<InboxState> {
  NotificationsRepository get _repo =>
      ref.read(notificationsRepositoryProvider);

  @override
  Future<InboxState> build() async {
    ref.watch(notificationsRepositoryProvider);
    final first = await _repo.page();
    return InboxState(items: first.items, hasMore: first.hasMore);
  }

  Future<void> refresh() async {
    state = const AsyncLoading<InboxState>().copyWithPrevious(state);
    state = await AsyncValue.guard(build);
    ref.invalidate(unreadCountProvider);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await _repo.page(page: current.page + 1);
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...next.items],
          hasMore: next.hasMore,
          page: current.page + 1,
          loadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  Future<void> markRead(String id) async {
    await _repo.markRead(id);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          items: [
            for (final n in current.items) n.id == id ? n.markedRead() : n,
          ],
        ),
      );
    }
    ref.invalidate(unreadCountProvider);
  }

  Future<void> markAllRead() async {
    await _repo.markAllRead();
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          items: [for (final n in current.items) n.markedRead()],
        ),
      );
    }
    ref.invalidate(unreadCountProvider);
  }
}

final inboxControllerProvider =
    AsyncNotifierProvider.autoDispose<InboxController, InboxState>(
      InboxController.new,
    );

/// Badge count. Refreshed on resume, after a push arrives, and after reads —
/// never polled on a timer.
final unreadCountProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(notificationsRepositoryProvider).unreadCount(),
);
