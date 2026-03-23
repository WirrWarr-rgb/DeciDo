

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';

// Провайдер для состояния аутентификации
final authStateProvider = StateProvider<UserModel?>((ref) => null);

// Провайдер для загрузки
final authLoadingProvider = StateProvider<bool>((ref) => false);