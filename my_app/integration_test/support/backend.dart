// Talks to the LOCAL backend directly (outside the app under test), as the
// synthetic demo parent from `php artisan mamily:demo-seed` and, for
// isolation checks, as a separately paired child install.
import 'package:dio/dio.dart';
import 'package:my_app/core/config/app_config.dart';

/// Synthetic credentials from `php artisan mamily:demo-seed` (local only).
const demoEmail = 'demo.parent@mamily.test';
const demoPassword = 'DemoFamily2026!';

Dio _dio([String? token]) => Dio(
  BaseOptions(
    baseUrl: AppConfig.fromEnvironment().apiBaseUrl,
    headers: {
      'Accept': 'application/json',
      'Accept-Language': 'en',
      'Authorization': ?(token == null ? null : 'Bearer $token'),
    },
    // Tests assert on status codes, so never throw on 4xx/5xx.
    validateStatus: (_) => true,
  ),
);

Map<String, dynamic> _data(Response<dynamic> r) {
  final body = r.data;
  if (r.statusCode == null || r.statusCode! >= 300 || body is! Map) {
    throw StateError('${r.requestOptions.path} → ${r.statusCode}: $body');
  }
  return (body['data'] as Map).cast<String, dynamic>();
}

List<Map<String, dynamic>> _list(Response<dynamic> r) {
  final body = r.data;
  if (r.statusCode == null || r.statusCode! >= 300 || body is! Map) {
    throw StateError('${r.requestOptions.path} → ${r.statusCode}: $body');
  }
  final d = body['data'];
  final items = d is Map ? (d['items'] ?? d['runs'] ?? d['data']) : d;
  return (items as List)
      .cast<Map>()
      .map((m) => m.cast<String, dynamic>())
      .toList();
}

/// Unique, readable names so runs never collide with seed data or each other.
String uniqueName(String prefix) =>
    '$prefix ${DateTime.now().millisecondsSinceEpoch % 100000}';

class ParentApi {
  ParentApi._(this.dio, this.familyId);

  final Dio dio;
  final String familyId;

  String get _f => '/families/$familyId';

  static Future<ParentApi> signIn() async {
    final login = await _dio().post<dynamic>(
      '/auth/login',
      data: {
        'login': demoEmail,
        'password': demoPassword,
        'device_name': 'integration-test',
      },
    );
    final token = _data(login)['token'] as String;
    final dio = _dio(token);
    final me = _data(await dio.get<dynamic>('/auth/me'));
    final family = (me['memberships'] as List).first['family'] as Map;
    return ParentApi._(dio, family['id'] as String);
  }

  Future<void> signOut() => dio.post<dynamic>('/auth/logout');

  Future<String> childId(String name) async {
    final kids = _list(await dio.get<dynamic>('$_f/children'));
    return kids.firstWhere((c) => c['name'] == name)['id'] as String;
  }

  Future<String> pairingCode(String childId) async =>
      _data(
            await dio.post<dynamic>('$_f/children/$childId/pairing-codes'),
          )['code']
          as String;

  Future<int> balance(String childId) async =>
      (_data(
                await dio.get<dynamic>('$_f/children/$childId/points-balance'),
              )['balance']
              as num)
          .toInt();

  Future<List<Map<String, dynamic>>> inbox() async =>
      _list(await dio.get<dynamic>('$_f/inbox'));

  // ---- tasks ---------------------------------------------------------------

  Future<String> createDailyTask(
    String childId,
    String title, {
    required int points,
  }) async =>
      _data(
            await dio.post<dynamic>(
              '$_f/children/$childId/tasks',
              data: {
                'title': title,
                'points': points,
                'recurrence_type': 'daily',
                'icon_key': 'pet',
              },
            ),
          )['id']
          as String;

  Future<void> archiveTask(String childId, String taskId) => dio.patch<dynamic>(
    '$_f/children/$childId/tasks/$taskId',
    data: {'status': 'archived'},
  );

  Future<int> approveCompletion(
    String childId,
    String taskId,
    String completionId,
  ) async => (await dio.post<dynamic>(
    '$_f/children/$childId/tasks/$taskId/completions/$completionId/approve',
    data: const <String, dynamic>{},
  )).statusCode!;

  // ---- rewards -------------------------------------------------------------

  Future<String> createReward(String title, {required int cost}) async =>
      _data(
            await dio.post<dynamic>(
              '$_f/rewards',
              data: {'title': title, 'type': 'privilege', 'points_cost': cost},
            ),
          )['id']
          as String;

  Future<void> deleteReward(String id) =>
      dio.delete<dynamic>('$_f/rewards/$id');

  Future<List<Map<String, dynamic>>> redemptions(String childId) async =>
      _list(await dio.get<dynamic>('$_f/children/$childId/reward-redemptions'));

  Future<int> approveRedemption(String childId, String id) async =>
      (await dio.post<dynamic>(
        '$_f/children/$childId/reward-redemptions/$id/approve',
        data: const <String, dynamic>{},
      )).statusCode!;

  // ---- routines ------------------------------------------------------------

  Future<String> createRoutine(
    String childId,
    String title, {
    required int bonus,
    required List<String> steps,
  }) async =>
      _data(
            await dio.post<dynamic>(
              '$_f/children/$childId/routines',
              data: {
                'title': title,
                'kind': 'custom',
                'days_of_week': [1, 2, 3, 4, 5, 6, 7],
                'bonus_points': bonus,
                'steps': [
                  for (final s in steps) {'title': s, 'icon_key': 'bed'},
                ],
              },
            ),
          )['id']
          as String;

  Future<void> deleteRoutine(String childId, String id) =>
      dio.delete<dynamic>('$_f/children/$childId/routines/$id');

  Future<List<Map<String, dynamic>>> routineRuns(String childId) async =>
      _list(await dio.get<dynamic>('$_f/children/$childId/routine-runs'));

  Future<int> approveRoutineRun(String childId, String runId) async =>
      (await dio.post<dynamic>(
        '$_f/children/$childId/routine-runs/$runId/approve',
        data: const <String, dynamic>{},
      )).statusCode!;

  // ---- devices -------------------------------------------------------------

  Future<List<Map<String, dynamic>>> devices(String childId) async =>
      _list(await dio.get<dynamic>('$_f/children/$childId/devices'));

  Future<int> unpair(String childId, String deviceId) async =>
      (await dio.delete<dynamic>(
        '$_f/children/$childId/devices/$deviceId',
      )).statusCode!;
}

/// A child install paired through the API only (no UI), for access checks.
class ChildApi {
  ChildApi._(this.dio);

  final Dio dio;

  static Future<ChildApi> pair(String code, {required String installId}) async {
    final r = await _dio().post<dynamic>(
      '/child-auth/pair',
      data: {
        'code': code,
        'device_name': 'integration-child',
        'platform': 'ios',
        'install_id_hash': installId,
      },
    );
    return ChildApi._(_dio(_data(r)['token'] as String));
  }

  Future<int> status(String method, String path) async =>
      (await dio.request<dynamic>(
        path,
        options: Options(method: method),
      )).statusCode!;

  Future<String?> deviceId() async =>
      _data(await dio.get<dynamic>('/child/me'))['device']?['id'] as String?;
}
