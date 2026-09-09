import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/core/providers.dart';
import 'package:my_app/features/auth/application/auth_controller.dart';
import 'package:my_app/features/auth/data/models/auth_user.dart';
import 'package:my_app/features/auth/data/models/family_membership.dart';
import 'package:my_app/features/children/application/selected_child_controller.dart';

import 'fake_secure_storage.dart';

/// Test-only handles for the active family / selected child, so tests can
/// simulate switching without standing up the full auth + children session.
final testActiveFamilyIdProvider = StateProvider<String?>((_) => null);
final testSelectedChildIdProvider = StateProvider<String?>((_) => null);

/// Records every outbound [RequestOptions] so tests can assert on headers.
class _CaptureInterceptor extends Interceptor {
  final List<RequestOptions> requests = [];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add(options);
    handler.next(options);
  }
}

/// A [ProviderContainer] wired to a mocked Dio adapter. The **real**
/// interceptors (auth / locale / logging) stay in place so header behaviour can
/// be asserted; only the transport is faked. No live server is ever contacted.
class TestApi {
  TestApi._(this.container, this.adapter, this.storage, this._capture);

  final ProviderContainer container;
  final DioAdapter adapter;
  final FakeSecureTokenStorage storage;
  final _CaptureInterceptor _capture;

  factory TestApi.create({
    String? token,
    String locale = 'ar',
    String? activeFamilyId,
    String? selectedChildId,
    FamilyRole role = FamilyRole.owner,
    List<Override> overrides = const [],
  }) {
    final storage = FakeSecureTokenStorage(
      token: token,
      locale: locale,
      activeFamilyId: activeFamilyId,
    );
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        initialLocaleProvider.overrideWithValue(Locale(locale)),
        testActiveFamilyIdProvider.overrideWith((ref) => activeFamilyId),
        testSelectedChildIdProvider.overrideWith((ref) => selectedChildId),
        // Route the real selectors through the test handles.
        activeFamilyIdProvider.overrideWith(
          (ref) => ref.watch(testActiveFamilyIdProvider),
        ),
        childScopeProvider.overrideWith(
          (ref) => (
            familyId: ref.watch(testActiveFamilyIdProvider),
            childId: ref.watch(testSelectedChildIdProvider),
          ),
        ),
        activeMembershipProvider.overrideWith(
          (ref) => ref.watch(testActiveFamilyIdProvider) == null
              ? null
              : FamilyMembership(
                  id: 'member-test',
                  role: role,
                  status: 'active',
                  family: FamilySummary(
                    id: ref.watch(testActiveFamilyIdProvider)!,
                    name: 'Test Family',
                  ),
                ),
        ),
        currentUserProvider.overrideWithValue(
          const AuthUser(id: 'user-test', firstName: 'Test', lastName: 'User'),
        ),
        ...overrides,
      ],
    );
    final dio = container.read(dioProvider);
    final capture = _CaptureInterceptor();
    dio.interceptors.add(capture);
    final adapter = DioAdapter(
      dio: dio,
      matcher: const FullHttpRequestMatcher(needsExactBody: false),
    );
    return TestApi._(container, adapter, storage, capture);
  }

  List<RequestOptions> get requests => _capture.requests;
  RequestOptions get lastRequest => _capture.requests.last;

  int get unauthorizedSignals => container.read(unauthorizedSignalProvider);

  /// Simulate the user switching to another family.
  void setActiveFamily(String? familyId) =>
      container.read(testActiveFamilyIdProvider.notifier).state = familyId;

  /// Simulate selecting a different child.
  void setSelectedChild(String? childId) =>
      container.read(testSelectedChildIdProvider.notifier).state = childId;

  void dispose() => container.dispose();
}
