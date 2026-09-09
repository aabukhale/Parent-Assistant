import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_envelope.dart';
import '../../children/application/selected_child_controller.dart';
import '../data/content_repository.dart';
import '../data/content_requests.dart';
import '../data/models/content_item.dart';

/// The child's effective content policy (server-authoritative). Child-scoped;
/// null scope → a [StateError] the UI renders as an error state.
final contentPolicyProvider =
    FutureProvider.autoDispose<EffectiveContentPolicy>((ref) {
      final scope = ref.watch(childScopeProvider);
      if (scope.familyId == null || scope.childId == null) {
        throw StateError('No active family / selected child');
      }
      return ref
          .watch(contentRepositoryProvider)
          .policy(scope.familyId!, scope.childId!);
    });

@immutable
class ContentRulesState {
  const ContentRulesState({required this.rules, required this.meta});

  final List<ContentRule> rules;
  final PageMeta meta;

  bool get isEmpty => rules.isEmpty;
}

/// The child's stored content rules. Child-scoped. After any mutation the list
/// **and** [contentPolicyProvider] are refreshed from the server (the effective
/// policy is derived, so it must be re-read — never patched locally).
class ContentRulesController extends AsyncNotifier<ContentRulesState> {
  ({String familyId, String childId})? _scope() {
    final scope = ref.read(childScopeProvider);
    if (scope.familyId == null || scope.childId == null) return null;
    return (familyId: scope.familyId!, childId: scope.childId!);
  }

  @override
  Future<ContentRulesState> build() async {
    final scope = ref.watch(childScopeProvider);
    if (scope.familyId == null || scope.childId == null) {
      return ContentRulesState(rules: const [], meta: PageMeta.single(0));
    }
    final page = await ref
        .read(contentRepositoryProvider)
        .listRules(scope.familyId!, scope.childId!);
    return ContentRulesState(rules: page.items, meta: page.meta);
  }

  Future<void> refresh() async {
    final scope = _scope();
    if (scope == null) return;
    state = await AsyncValue.guard(() async {
      final page = await ref
          .read(contentRepositoryProvider)
          .listRules(scope.familyId, scope.childId);
      return ContentRulesState(rules: page.items, meta: page.meta);
    });
  }

  Future<ContentRule> saveRule(ContentRuleInput input) async {
    final scope = _scope();
    if (scope == null) throw StateError('No active family / selected child');
    final rule = await ref
        .read(contentRepositoryProvider)
        .saveRule(scope.familyId, scope.childId, input);
    await refresh();
    ref.invalidate(contentPolicyProvider);
    return rule;
  }

  Future<void> deleteRule(String ruleId) async {
    final scope = _scope();
    if (scope == null) return;
    await ref
        .read(contentRepositoryProvider)
        .deleteRule(scope.familyId, scope.childId, ruleId);
    await refresh();
    ref.invalidate(contentPolicyProvider);
  }

  /// `PUT …/content-policy`. On failure the caller keeps the real server value
  /// (this method rethrows and does not touch local state optimistically).
  Future<void> setAgeFilter({required bool enabled}) async {
    final scope = _scope();
    if (scope == null) throw StateError('No active family / selected child');
    await ref
        .read(contentRepositoryProvider)
        .setAgeFilter(scope.familyId, scope.childId, enabled: enabled);
    ref.invalidate(contentPolicyProvider);
  }
}

final contentRulesControllerProvider =
    AsyncNotifierProvider<ContentRulesController, ContentRulesState>(
      ContentRulesController.new,
    );

@immutable
class ContentCatalogState {
  const ContentCatalogState({
    required this.items,
    required this.meta,
    this.loadingMore = false,
  });

  final List<ContentItem> items;
  final PageMeta meta;
  final bool loadingMore;

  bool get isEmpty => items.isEmpty;
  bool get hasMore => meta.hasMore;

  ContentCatalogState copyWith({
    List<ContentItem>? items,
    PageMeta? meta,
    bool? loadingMore,
  }) => ContentCatalogState(
    items: items ?? this.items,
    meta: meta ?? this.meta,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// The read-only content catalog. Not family-scoped (a public catalog), but the
/// browse screen passes the selected child's age so the age filter matches.
class ContentCatalogController extends AsyncNotifier<ContentCatalogState> {
  static const _perPage = 20;

  int? _age;

  @override
  Future<ContentCatalogState> build() async {
    _age = ref.watch(selectedChildProvider)?.age;
    final page = await ref
        .read(contentRepositoryProvider)
        .listCatalog(age: _age, perPage: _perPage);
    return ContentCatalogState(items: page.items, meta: page.meta);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      final page = await ref
          .read(contentRepositoryProvider)
          .listCatalog(age: _age, perPage: _perPage);
      return ContentCatalogState(items: page.items, meta: page.meta);
    });
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref
          .read(contentRepositoryProvider)
          .listCatalog(
            age: _age,
            page: current.meta.nextPage,
            perPage: _perPage,
          );
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          meta: page.meta,
          loadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
      rethrow;
    }
  }
}

final contentCatalogControllerProvider =
    AsyncNotifierProvider<ContentCatalogController, ContentCatalogState>(
      ContentCatalogController.new,
    );
