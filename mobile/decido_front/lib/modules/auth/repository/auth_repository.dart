

import 'package:decido_front/config/env/env_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../models/user_model.dart';
import '../models/token_model.dart';

class AuthRepository {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  Future<UserModel> register({
    required String username,
    required String email,
    required String password,
  }) async {
    if (AppConfig.useMocks) {
      return _mockRegister(
        username: username,
        email: email,
        password: password,
      );
    } else {
      return _realRegister(
        username: username,
        email: email,
        password: password,
      );
    }
  }
  
Future<UserModel> _realRegister({
  required String username,
  required String email,
  required String password,
}) async {
  try {
    final response = await DioClient.post('/auth/register', data: {
      'username': username,
      'email': email,
      'password': password,
    });
    
    print('Register response: ${response.data}');
    
    final userData = response.data;
    final user = UserModel.fromJson(userData);
    
    await _loginAfterRegistration(
      email: email,
      password: password,
    );
    
    return user;
  } on DioException catch (e) {
    print('DioException in register: ${e.message}');
    print('Response status: ${e.response?.statusCode}');
    print('Response data: ${e.response?.data}');
    
    if (e.response?.statusCode == 422) {
      final errors = e.response?.data;
      if (errors != null && errors['detail'] != null) {
        final errorMessages = (errors['detail'] as List)
            .map((err) => err['msg'] as String)
            .join(', ');
        throw Exception(errorMessages);
      }
    } else if (e.response?.statusCode == 405) {
      throw Exception('CORS Error: Сервер не принимает запросы. Проверьте настройки CORS на бэкенде.');
    } else if (e.type == DioExceptionType.connectionTimeout) {
      throw Exception('Таймаут подключения. Проверьте, запущен ли бэкенд.');
    } else if (e.type == DioExceptionType.connectionError) {
      throw Exception('Нет подключения к серверу. Проверьте, запущен ли бэкенд на ${EnvConfig.apiBaseUrl}');
    }
    
    throw Exception('Ошибка регистрации: ${e.message}');
  } catch (e) {
    print('Unexpected error in register: $e');
    throw Exception('Ошибка регистрации: $e');
  }
}
  
  Future<void> _loginAfterRegistration({
    required String email,
    required String password,
  }) async {
    // Используем FormData для application/x-www-form-urlencoded
    final formData = FormData.fromMap({
      'email': email,
      'password': password,
    });
    
    final response = await DioClient.post(
      '/auth/login',
      data: formData,
      options: Options(
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      ),
    );
    
    final token = TokenModel.fromJson(response.data);
    await _storage.write(key: 'access_token', value: token.accessToken);
  }
  
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    if (AppConfig.useMocks) {
      return _mockLogin(
        email: email,
        password: password,
      );
    } else {
      return _realLogin(
        email: email,
        password: password,
      );
    }
  }
  
  Future<UserModel> _realLogin({
    required String email,
    required String password,
  }) async {
    try {
      // Используем FormData для application/x-www-form-urlencoded
      final formData = FormData.fromMap({
        'email': email,
        'password': password,
      });
      
      final response = await DioClient.post(
        '/auth/login',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );
      
      final token = TokenModel.fromJson(response.data);
      await _storage.write(key: 'access_token', value: token.accessToken);
      
      // Получаем данные пользователя
      return await getCurrentUser();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Неверный email или пароль');
      }
      throw Exception('Ошибка входа: ${e.message}');
    }
  }
  
  Future<UserModel> getCurrentUser() async {
    if (AppConfig.useMocks) {
      final username = await _storage.read(key: 'current_user');
      if (username == null) throw Exception('Не авторизован');
      
      final user = AppConfig.users[username];
      if (user == null) throw Exception('Пользователь не найден');
      
      return UserModel(
        id: user['id'] as int,
        username: username,
        email: user['email'] as String,
        isActive: user['is_active'] as bool,
      );
    } else {
      try {
        final response = await DioClient.get('/users/me');
        return UserModel.fromJson(response.data);
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          throw Exception('Сессия истекла');
        }
        throw Exception('Ошибка получения профиля: ${e.message}');
      }
    }
  }
  
  Future<bool> checkAuth() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) return false;
    
    if (AppConfig.useMocks) {
      return token.startsWith('mock_access_token');
    } else {
      try {
        await DioClient.get('/users/me');
        return true;
      } catch (e) {
        return false;
      }
    }
  }
  
  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'current_user');
  }
  
  // Мок-методы для тестирования
  Future<UserModel> _mockRegister({
    required String username,
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay));
    
    if (AppConfig.isUsernameExists(username)) {
      throw Exception('Пользователь с таким ником уже существует');
    }
    if (AppConfig.isEmailExists(email)) {
      throw Exception('Пользователь с таким email уже существует');
    }
    
    AppConfig.addUser(username, email, password);
    
    final accessToken = 'mock_access_token_${DateTime.now().millisecondsSinceEpoch}';
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'current_user', value: username);
    
    return UserModel(
      id: AppConfig.users[username]!['id'] as int,
      username: username,
      email: email,
      isActive: true,
    );
  }
  
  Future<UserModel> _mockLogin({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay));
    
    Map<String, dynamic>? foundUser;
    String? foundUsername;
    
    for (var entry in AppConfig.users.entries) {
      if (entry.value['email'] == email && entry.value['password'] == password) {
        foundUser = entry.value;
        foundUsername = entry.key;
        break;
      }
    }
    
    if (foundUser == null) {
      throw Exception('Неверный email или пароль');
    }
    
    final accessToken = 'mock_access_token_${DateTime.now().millisecondsSinceEpoch}';
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'current_user', value: foundUsername);
    
    return UserModel(
      id: foundUser['id'] as int,
      username: foundUsername!,
      email: foundUser['email'] as String,
      isActive: foundUser['is_active'] as bool,
    );
  }
}