

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../models/user_model.dart';

class AuthRepository {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  Future<UserModel> register({
    required String username,
    required String email,
    required String password,
  }) async {
    if (AppConfig.useMocks) {
      // Мок-режим
      await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay));
      
      // Проверяем существование пользователя
      if (AppConfig.isUsernameExists(username)) {
        throw Exception('Пользователь с таким ником уже существует');
      }
      if (AppConfig.isEmailExists(email)) {
        throw Exception('Пользователь с таким email уже существует');
      }
      
      // Создаем пользователя
      AppConfig.addUser(username, email, password);
      
      // Создаем токены
      final accessToken = 'mock_access_token_${DateTime.now().millisecondsSinceEpoch}';
      final refreshToken = 'mock_refresh_token_${DateTime.now().millisecondsSinceEpoch}';
      
      // Сохраняем токены
      await _storage.write(key: 'access_token', value: accessToken);
      await _storage.write(key: 'refresh_token', value: refreshToken);
      await _storage.write(key: 'current_user', value: username);
      
      return UserModel(
        id: AppConfig.users[username]!['id'] as int,
        username: username,
        email: email,
        avatarUrl: null,
      );
    } else {
      // Реальный API
      final response = await DioClient.post('/auth/register', data: {
        'username': username,
        'email': email,
        'password': password,
      });
      
      final data = response.data;
      
      await _storage.write(key: 'access_token', value: data['access_token']);
      await _storage.write(key: 'refresh_token', value: data['refresh_token']);
      await _storage.write(key: 'current_user', value: username);
      
      return UserModel.fromJson(data['user']);
    }
  }
  
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    if (AppConfig.useMocks) {
      // Мок-режим
      await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay));
      
      // Ищем пользователя
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
      
      // Создаем токены
      final accessToken = 'mock_access_token_${DateTime.now().millisecondsSinceEpoch}';
      final refreshToken = 'mock_refresh_token_${DateTime.now().millisecondsSinceEpoch}';
      
      // Сохраняем токены
      await _storage.write(key: 'access_token', value: accessToken);
      await _storage.write(key: 'refresh_token', value: refreshToken);
      await _storage.write(key: 'current_user', value: foundUsername);
      
      return UserModel(
        id: foundUser['id'] as int,
        username: foundUsername!,
        email: foundUser['email'] as String,
        avatarUrl: foundUser['avatar_url'],
      );
    } else {
      // Реальный API
      final response = await DioClient.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      
      final data = response.data;
      
      await _storage.write(key: 'access_token', value: data['access_token']);
      await _storage.write(key: 'refresh_token', value: data['refresh_token']);
      await _storage.write(key: 'current_user', value: data['user']['username']);
      
      return UserModel.fromJson(data['user']);
    }
  }
  
  Future<UserModel?> getCurrentUser() async {
    if (AppConfig.useMocks) {
      final username = await _storage.read(key: 'current_user');
      if (username == null) return null;
      
      final user = AppConfig.users[username];
      if (user == null) return null;
      
      return UserModel(
        id: user['id'] as int,
        username: username,
        email: user['email'] as String,
        avatarUrl: user['avatar_url'],
      );
    } else {
      try {
        final response = await DioClient.get('/users/me');
        return UserModel.fromJson(response.data);
      } catch (e) {
        return null;
      }
    }
  }
  
  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'current_user');
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
}