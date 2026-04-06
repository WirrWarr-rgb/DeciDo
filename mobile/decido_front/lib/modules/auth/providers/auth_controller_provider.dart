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
      return null;
    } catch (e) {
      print('Register error: $e');
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
      return null;
    } catch (e) {
      print('Login error: $e');
      return e.toString();
    }
  }
  
  Future<void> checkAuth() async {
    print('checkAuth started');
    final isAuth = await _repository.checkAuth();
    print('isAuth: $isAuth');
    
    if (isAuth) {
      try {
        final user = await _repository.getCurrentUser();
        print('User restored: ${user.username}');
        _ref.read(authStateProvider.notifier).state = user;
      } catch (e) {
        print('Failed to restore user: $e');
        _ref.read(authStateProvider.notifier).state = null;
      }
    } else {
      print('Not authenticated');
      _ref.read(authStateProvider.notifier).state = null;
    }
    print('checkAuth completed');
  }
  
  Future<void> logout() async {
    await _repository.logout();
    _ref.read(authStateProvider.notifier).state = null;
  }
}