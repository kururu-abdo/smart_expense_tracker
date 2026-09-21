import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'models.dart';

class Api {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );
  final Dio dio;
  final FlutterSecureStorage storage;
  String? accessToken, refreshToken;
  Future<void>? _refreshing;
  Future<void> _storageQueue = Future.value();
  int _sessionEpoch = 0;
  Api({Dio? client, FlutterSecureStorage? secureStorage})
    : dio =
          client ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
            ),
          ),
      storage = secureStorage ?? const FlutterSecureStorage();

  Future<void> restore() async {
    if (kReleaseMode && !baseUrl.startsWith('https://')) {
      throw const ApiFailure('https_required');
    }
    final value = await storage.read(key: 'masar.session');
    if (value != null) {
      try {
        final data = jsonDecode(value);
        accessToken = data['access_token'];
        refreshToken = data['refresh_token'];
      } catch (_) {
        await clear();
      }
    }
  }

  Future<void> saveTokens(Map<String, dynamic> data) async {
    final epoch = ++_sessionEpoch;
    _refreshing = null;
    await _storeTokens(data, epoch);
  }

  Future<void> _storeTokens(Map<String, dynamic> data, int epoch) async {
    if (epoch != _sessionEpoch) throw const ApiFailure('session_expired');
    accessToken = data['access_token'];
    refreshToken = data['refresh_token'];
    _storageQueue = _storageQueue.catchError((_) {}).then((_) async {
      if (epoch != _sessionEpoch) return;
      await storage.write(
        key: 'masar.session',
        value: jsonEncode({
          'access_token': data['access_token'],
          'refresh_token': data['refresh_token'],
        }),
      );
    });
    await _storageQueue;
  }

  Future<void> clear() async {
    _sessionEpoch++;
    _refreshing = null;
    accessToken = null;
    refreshToken = null;
    _storageQueue = _storageQueue
        .catchError((_) {})
        .then((_) => storage.delete(key: 'masar.session'));
    await _storageQueue;
  }

  Future<void> _refresh() async {
    final epoch = _sessionEpoch;
    try {
      final response = await dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      await _storeTokens(Map<String, dynamic>.from(response.data), epoch);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        if (epoch == _sessionEpoch) await clear();
        throw const ApiFailure('session_expired');
      }
      throw const ApiFailure('network_error');
    }
  }

  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool auth = true,
    bool text = false,
  }) async {
    if (kReleaseMode && !baseUrl.startsWith('https://')) {
      throw const ApiFailure('https_required');
    }
    final sentToken = accessToken;
    final epoch = _sessionEpoch;
    Future<Response> send() => dio.request(
      path,
      data: data,
      queryParameters: query,
      options: Options(
        method: method,
        responseType: text ? ResponseType.plain : ResponseType.json,
        headers: auth && accessToken != null
            ? {'Authorization': 'Bearer $accessToken'}
            : null,
      ),
    );
    try {
      final response = await send();
      if (auth && epoch != _sessionEpoch) {
        throw const ApiFailure('session_expired');
      }
      return response.data;
    } on DioException catch (e) {
      if (auth && epoch != _sessionEpoch) {
        throw const ApiFailure('session_expired');
      }
      if (auth && e.response?.statusCode == 401 && refreshToken != null) {
        if (sentToken == accessToken) {
          final active = _refreshing ??= _refresh();
          try {
            await active;
          } finally {
            if (identical(active, _refreshing)) _refreshing = null;
          }
        }
        if (epoch != _sessionEpoch) throw const ApiFailure('session_expired');
        try {
          final response = await send();
          if (epoch != _sessionEpoch) throw const ApiFailure('session_expired');
          return response.data;
        } on DioException catch (second) {
          throw _failure(second);
        }
      }
      throw _failure(e);
    }
  }

  ApiFailure _failure(DioException e) {
    final body = e.response?.data;
    final detail = body is Map ? body['detail'] : null;
    return ApiFailure(
      detail is String
          ? detail
          : e.response?.statusCode == 422
          ? 'invalid_input'
          : 'network_error',
    );
  }
}
