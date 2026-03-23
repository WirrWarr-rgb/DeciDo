

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/auth_repository.dart';
import '../models/user_model.dart';
import 'auth_state_provider.dart';

final authControllerProvider = Provider((ref) => AuthController(ref));

class AuthController {
  final Ref _ref;
  final AuthRepository _repository = AuthRepository();
  
  AuthController(this._ref);
  
  Future<String?> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final user = await _repository.register(
        username: username,
        email: email,
        password: password,
      );
      
      _ref.read(authStateProvider.notifier).state = user;
      return null; // Нет ошибки
    } catch (e) {
      return e.toString();
    }
  }
  
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _repository.login(
        email: email,
        password: password,
      );
      
      _ref.read(authStateProvider.notifier).state = user;
      return null; // Нет ошибки
    } catch (e) {
      return e.toString();
    }
  }
  
  Future<void> checkAuth() async {
    final isAuth = await _repository.checkAuth();
    if (isAuth) {
      try {
        final user = await _repository.getCurrentUser();
        _ref.read(authStateProvider.notifier).state = user;
      } catch (e) {
        _ref.read(authStateProvider.notifier).state = null;
      }
    } else {
      _ref.read(authStateProvider.notifier).state = null;
    }
  }
  
  Future<void> logout() async {
    await _repository.logout();
    _ref.read(authStateProvider.notifier).state = null;
  }
}