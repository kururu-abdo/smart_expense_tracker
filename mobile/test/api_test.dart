import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masar/core/api.dart';
import 'package:masar/core/models.dart';

class Adapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) handle;
  Adapter(this.handle);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handle(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody response(int status, Object data) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'Concurrent expired requests share one refresh and keep both results',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
      var refreshes = 0;
      dio.httpClientAdapter = Adapter((options) async {
        if (options.path == '/auth/refresh') {
          refreshes++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return response(200, {
            'access_token': 'new',
            'refresh_token': 'new-refresh',
          });
        }
        return options.headers['Authorization'] == 'Bearer new'
            ? response(200, {'ok': true})
            : response(401, {'detail': 'session_expired'});
      });
      final api = Api(client: dio);
      await api.saveTokens({
        'access_token': 'old',
        'refresh_token': 'old-refresh',
      });
      final results = await Future.wait([
        api.request('GET', '/one'),
        api.request('GET', '/two'),
      ]);
      expect(refreshes, 1);
      expect(results.every((r) => r['ok'] == true), isTrue);
    },
  );
  test('An in-flight refresh cannot restore a logged-out session', () async {
    final started = Completer<void>(), finish = Completer<void>();
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
    dio.httpClientAdapter = Adapter((options) async {
      if (options.path == '/auth/refresh') {
        started.complete();
        await finish.future;
        return response(200, {
          'access_token': 'new',
          'refresh_token': 'new-refresh',
        });
      }
      return response(401, {'detail': 'session_expired'});
    });
    final api = Api(client: dio);
    await api.saveTokens({
      'access_token': 'old',
      'refresh_token': 'old-refresh',
    });
    final pending = api.request('GET', '/private');
    final assertion = expectLater(pending, throwsA(isA<ApiFailure>()));
    await started.future;
    await api.clear();
    finish.complete();
    await assertion;
    expect(api.accessToken, isNull);
    expect(await api.storage.read(key: 'masar.session'), isNull);
  });
}
