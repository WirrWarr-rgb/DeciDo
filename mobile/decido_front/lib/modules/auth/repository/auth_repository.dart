import 'package:decido_front/config/env/env_config.dart';
import 'package:decido_front/core/storage/secure_storage.dart';
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
      
      // API возвращает Token
      final token = TokenModel.fromJson(response.data);
      await SecureStorage.saveAccessToken(token.accessToken);
      
      // Получаем данные пользователя
      final user = await getCurrentUser();
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
      await SecureStorage.saveAccessToken(token.accessToken);
      
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
      final username = await SecureStorage.getCurrentUser();
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
        print('getCurrentUser response: ${response.data}');
        return UserModel.fromJson(response.data);
      } on DioException catch (e) {
        print('getCurrentUser error: ${e.message}');
        if (e.response?.statusCode == 401) {
          await SecureStorage.clear();
          throw Exception('Сессия истекла');
        }
        throw Exception('Ошибка получения профиля: ${e.message}');
      }
    }
  }
  
  Future<bool> checkAuth() async {
    final token = await SecureStorage.getAccessToken();
    print('CheckAuth: token = $token');
    
    if (token == null || token.isEmpty) {
      print('No token found');
      return false;
    }
    
    if (AppConfig.useMocks) {
      return token.startsWith('mock_access_token');
    } else {
      try {
        final response = await DioClient.get('/users/me');
        print('User data: ${response.data}');
        return true;
      } catch (e) {
        print('Token validation failed: $e');
        await SecureStorage.clear();
        return false;
      }
    }
  }
  
  Future<void> logout() async {
    await SecureStorage.clear();
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
    await SecureStorage.saveAccessToken(accessToken);
    await SecureStorage.saveCurrentUser(username);
    
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
    await SecureStorage.saveAccessToken(accessToken);
    await SecureStorage.saveCurrentUser(foundUsername!);
    
    return UserModel(
      id: foundUser['id'] as int,
      username: foundUsername,
      email: foundUser['email'] as String,
      isActive: foundUser['is_active'] as bool,
    );
  }
}