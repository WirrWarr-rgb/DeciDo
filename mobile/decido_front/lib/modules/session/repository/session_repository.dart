import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../models/session_models.dart';
import 'i_session_repository.dart';

class SessionRepository implements ISessionRepository {
  // ============= HTTP API =============
  
  /// Создать лобби
  @override
  Future<SessionModel> createLobby(CreateLobbyRequest request) async {
    try {
      final response = await DioClient.post('/sessions/', data: request.toJson());
      return SessionModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Ошибка создания лобби: $e');
    }
  }
  
  /// Получить информацию о лобби
  @override
  Future<SessionModel> getLobby(int sessionId) async {
    try {
      final response = await DioClient.get('/sessions/$sessionId');
      return SessionModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Ошибка загрузки лобби: $e');
    }
  }
  
  /// Отметить готовность
  @override
  Future<void> markReady(int sessionId) async {
    try {
      await DioClient.post('/sessions/$sessionId/ready');
    } catch (e) {
      throw Exception('Ошибка отметки готовности: $e');
    }
  }
  
  /// Принудительно начать голосование (только владелец)
  @override
  Future<void> forceStart(int sessionId) async {
    try {
      await DioClient.post('/sessions/$sessionId/start');
    } catch (e) {
      throw Exception('Ошибка старта голосования: $e');
    }
  }
  
  /// Отправить голос
  @override
  Future<Map<String, dynamic>> submitVote(
    int sessionId, {
    List<int>? rankedItemIds,
    bool spin = false,
  }) async {
    try {
      final response = await DioClient.post(
        '/sessions/$sessionId/vote',
        data: VoteRequest(rankedItemIds: rankedItemIds, spin: spin).toJson(),
      );
      return response.data;
    } catch (e) {
      throw Exception('Ошибка отправки голоса: $e');
    }
  }
  
  /// Получить результаты
  @override
  Future<Map<String, dynamic>> getResults(int sessionId) async {
    try {
      final response = await DioClient.get('/sessions/$sessionId/results');
      return response.data;
    } catch (e) {
      throw Exception('Ошибка получения результатов: $e');
    }
  }
  
  /// Выйти из лобби
  @override
  Future<void> leaveLobby(int sessionId) async {
    try {
      await DioClient.post('/sessions/$sessionId/leave');
    } catch (e) {
      throw Exception('Ошибка выхода из лобби: $e');
    }
  }
  
  /// Закрыть лобби (только владелец)
  @override
  Future<void> closeLobby(int sessionId) async {
    try {
      await DioClient.post('/sessions/$sessionId/close');
    } catch (e) {
      throw Exception('Ошибка закрытия лобби: $e');
    }
  }
  
  /// Вернуться в лобби после результатов (только владелец)
  @override
  Future<void> backToLobby(int sessionId) async {
    try {
      await DioClient.post('/sessions/$sessionId/back-to-lobby');
    } catch (e) {
      throw Exception('Ошибка возврата в лобби: $e');
    }
  }
  
  /// Добавить пункт в список
  @override
  Future<SessionListItemModel> addItem(
    int sessionId, {
    required String name,
    String? description,
    String? imageUrl,
  }) async {
    try {
      final response = await DioClient.post(
        '/sessions/$sessionId/list/items',
        data: {
          'name': name,
          'description': description,
          'image_url': imageUrl,
        },
      );
      return SessionListItemModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Ошибка добавления пункта: $e');
    }
  }
  
  /// Обновить пункт
  @override
  Future<SessionListItemModel> updateItem(
    int sessionId,
    int itemId, {
    String? name,
    String? description,
    String? imageUrl,
  }) async {
    try {
      final response = await DioClient.put(
        '/sessions/$sessionId/list/items/$itemId',
        data: {
          'name': name,
          'description': description,
          'image_url': imageUrl,
        },
      );
      return SessionListItemModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Ошибка обновления пункта: $e');
    }
  }
  
  /// Удалить пункт
  @override
  Future<void> deleteItem(int sessionId, int itemId) async {
    try {
      await DioClient.delete('/sessions/$sessionId/list/items/$itemId');
    } catch (e) {
      throw Exception('Ошибка удаления пункта: $e');
    }
  }
  
  /// Обновить порядок пунктов
  @override
  Future<void> updateOrder(int sessionId, List<Map<String, int>> itemsOrder) async {
    try {
      await DioClient.put(
        '/sessions/$sessionId/list/items/order',
        data: {'items': itemsOrder},
      );
    } catch (e) {
      throw Exception('Ошибка обновления порядка: $e');
    }
  }
  
  /// Выгнать участника (только владелец)
  @override
  Future<void> kickParticipant(int sessionId, int userId) async {
    try {
      await DioClient.delete('/sessions/$sessionId/participants/$userId');
    } catch (e) {
      throw Exception('Ошибка исключения участника: $e');
    }
  }
  
  /// Пригласить друзей (только владелец)
  @override
  Future<void> inviteFriends(int sessionId, List<int> friendIds) async {
    try {
      await DioClient.post(
        '/sessions/$sessionId/invite',
        data: {'friend_ids': friendIds},
      );
    } catch (e) {
      throw Exception('Ошибка приглашения друзей: $e');
    }
  }
  
  /// Заблокировать список (только владелец)
  @override
  Future<void> lockList(int sessionId) async {
    try {
      await DioClient.post('/sessions/$sessionId/list/lock');
    } catch (e) {
      throw Exception('Ошибка блокировки списка: $e');
    }
  }
  
  /// Разблокировать список (только владелец)
  @override
  Future<void> unlockList(int sessionId) async {
    try {
      await DioClient.post('/sessions/$sessionId/list/unlock');
    } catch (e) {
      throw Exception('Ошибка разблокировки списка: $e');
    }
  }
}