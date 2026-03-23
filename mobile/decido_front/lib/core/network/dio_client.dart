//# Настройка Dio (интерцепторы, базовый URL)

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_exceptions.dart';
import '../../config/env/env_config.dart';

class DioClient {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: EnvConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
    },
  ));
  
  static final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  static void init() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException error, handler) async {
        if (error.response?.statusCode == 401) {
          // Попытка обновить токен
          final newToken = await _refreshToken();
          if (newToken != null) {
            error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            final response = await _dio.fetch(error.requestOptions);
            return handler.resolve(response);
          }
        }
        return handler.next(error);
      },
    ));
  }
  
  static Future<String?> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) return null;
      
      final response = await _dio.post('/auth/refresh', data: {
        'refresh_token': refreshToken,
      });
      
      final newAccessToken = response.data['access_token'];
      await _storage.write(key: 'access_token', value: newAccessToken);
      return newAccessToken;
    } catch (e) {
      return null;
    }
  }
  
  static Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
  
  static Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.post(path, data: data, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
  
  static Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.put(path, data: data, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
  
  static Future<Response> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.delete(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}