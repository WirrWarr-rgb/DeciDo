

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/auth_repository.dart';
import '../models/user_model.dart';
import 'auth_state_provider.dart';

final authControllerProvider = Provider((ref) => AuthController(ref));

class AuthController {
  final Ref _ref;
  final AuthRepository _repository = AuthRepository();
  
  AuthController(this._ref);
  
  Future<bool> register({
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
      return true;
    } catch (e) {
      print('Register error: $e');
      return false;
    }
  }
  
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _repository.login(
        email: email,
        password: password,
      );
      
      _ref.read(authStateProvider.notifier).state = user;
      return true;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }
  
  Future<void> checkAuth() async {
    final isAuth = await _repository.checkAuth();
    if (isAuth) {
      final user = await _repository.getCurrentUser();
      _ref.read(authStateProvider.notifier).state = user;
    } else {
      _ref.read(authStateProvider.notifier).state = null;
    }
  }
  
  Future<void> logout() async {
    await _repository.logout();
    _ref.read(authStateProvider.notifier).state = null;
  }
}