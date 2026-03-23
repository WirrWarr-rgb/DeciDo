

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/home_repository.dart';
import 'home_state_provider.dart';

final homeControllerProvider = Provider((ref) => HomeController(ref));

class HomeController {
  final Ref _ref;
  final HomeRepository _repository = HomeRepository();
  
  HomeController(this._ref);
  
  Future<void> loadDashboard() async {
    try {
      _ref.read(homeLoadingProvider.notifier).state = true;
      
      final dashboard = await _repository.getDashboard();
      
      _ref.read(homeStateProvider.notifier).state = AsyncValue.data(dashboard);
    } catch (error, stackTrace) {
      _ref.read(homeStateProvider.notifier).state = AsyncValue.error(error, stackTrace);
    } finally {
      _ref.read(homeLoadingProvider.notifier).state = false;
    }
  }
  
  Future<void> refreshDashboard() async {
    await loadDashboard();
  }
}