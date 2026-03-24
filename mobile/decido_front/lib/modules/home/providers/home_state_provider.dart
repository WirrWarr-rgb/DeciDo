

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dashboard_model.dart';

// Провайдер состояния главного экрана
final homeStateProvider = StateProvider<AsyncValue<DashboardModel>>(
  (ref) => const AsyncValue.loading(),
);

// Провайдер загрузки
final homeLoadingProvider = StateProvider<bool>((ref) => false);