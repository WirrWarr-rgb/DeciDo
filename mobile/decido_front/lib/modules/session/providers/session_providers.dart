import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_config.dart';
import '../repository/i_session_repository.dart';
import '../repository/session_repository.dart';
import '../repository/mock_session_repository.dart';
import '../services/websocket_service.dart';
import '../models/session_models.dart';

// Провайдер для репозитория - возвращает ISessionRepository
final sessionRepositoryProvider = Provider<ISessionRepository>((ref) {
  if (AppConfig.useMocks) {
    return MockSessionRepository();
  }
  return SessionRepository();
});

final webSocketServiceProvider = Provider((ref) => WebSocketService.instance);

final currentSessionProvider = StateProvider<SessionModel?>((ref) => null);

// selectedFriendsProvider хранит List<int>, а не List<Map>
final selectedFriendsProvider = StateProvider<List<int>>((ref) => []);

final selectedListIdProvider = StateProvider<int?>((ref) => null);
final selectedListNameProvider = StateProvider<String?>((ref) => null);

final sessionLoadingProvider = StateProvider<bool>((ref) => false);

final sessionErrorProvider = StateProvider<String?>((ref) => null);