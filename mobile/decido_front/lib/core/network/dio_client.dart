

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
    // Добавляем логгер для отладки
    _dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: true,
      responseBody: true,
      error: true,
    ));
    
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException error, handler) async {
        print('Dio Error: ${error.message}');
        print('Dio Error Response: ${error.response}');
        
        if (error.response?.statusCode == 401) {
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
    Options? options,
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      print('GET Error: ${e.message}');
      print('GET Error Response: ${e.response}');
      throw ApiException.fromDioError(e);
    }
  }
  
  static Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      print('POST Error: ${e.message}');
      print('POST Error Response: ${e.response}');
      print('POST Error Data: ${e.response?.data}');
      throw ApiException.fromDioError(e);
    }
  }
  
  static Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      print('PUT Error: ${e.message}');
      throw ApiException.fromDioError(e);
    }
  }
  
  static Future<Response> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      print('DELETE Error: ${e.message}');
      throw ApiException.fromDioError(e);
    }
  }
}