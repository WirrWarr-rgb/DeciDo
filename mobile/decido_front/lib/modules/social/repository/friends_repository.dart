import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../models/friend_model.dart';
import '../models/friend_request_model.dart';
import '../models/user_search_model.dart';

class FriendsRepository {
  // Получить список друзей
  Future<List<FriendModel>> getFriends() async {
    try {
      final response = await DioClient.get('/friends/');
      final List<dynamic> data = response.data;
      return data.map((json) => FriendModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Ошибка загрузки друзей: $e');
    }
  }

  // Получить список ID друзей
  Future<Set<int>> getFriendIds() async {
    try {
      final friends = await getFriends();
      return friends.map((f) => f.id).toSet();
    } catch (e) {
      return {};
    }
  }
  
  // Удалить друга
  Future<void> removeFriend(int friendId) async {
    try {
      await DioClient.delete('/friends/$friendId');
    } catch (e) {
      throw Exception('Ошибка удаления друга: $e');
    }
  }
  
  // Получить входящие заявки
  Future<List<FriendRequestModel>> getIncomingRequests() async {
    try {
      final response = await DioClient.get('/friends/requests/incoming');
      final List<dynamic> data = response.data;
      return data.map((json) => FriendRequestModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Ошибка загрузки заявок: $e');
    }
  }
  
  // Принять заявку
  Future<void> acceptRequest(int requestId) async {
    try {
      await DioClient.put('/friends/requests/$requestId/accept');
    } catch (e) {
      throw Exception('Ошибка принятия заявки: $e');
    }
  }
  
  // Отклонить заявку
  Future<void> rejectRequest(int requestId) async {
    try {
      await DioClient.put('/friends/requests/$requestId/reject');
    } catch (e) {
      throw Exception('Ошибка отклонения заявки: $e');
    }
  }
  
  // Поиск пользователей
  Future<List<UserSearchModel>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    
    try {
      final response = await DioClient.get(
        '/users/search/',
        queryParameters: {'q': query, 'limit': 20},
      );
      final List<dynamic> data = response.data;
      return data.map((json) => UserSearchModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Ошибка поиска: $e');
    }
  }



  // TODO: Перейти на прямой эндпоинт 
  // Получить пользователя по ID (прямой эндпоинт)
  Future<UserSearchModel> getUserById(int userId) async {
    try {
      // Пробуем получить через эндпоинт /users/{user_id}
      final response = await DioClient.get('/users/$userId');
      return UserSearchModel.fromJson(response.data);
    } catch (e) {
      print('Error getting user by ID $userId: $e');
      // Если эндпоинт не существует, возвращаем заглушку
      return UserSearchModel(
        id: userId,
        username: 'Пользователь #$userId',
        email: '',
        isActive: true,
      );
    }
  }

  /*
  // Альтернативный метод - через поиск с фильтрацией по ID
  Future<UserSearchModel> getUserById(int userId) async {
    try {
      // Ищем пользователя по username (если username это число)
      // или получаем всех пользователей и фильтруем
      final response = await DioClient.get(
        '/users/search/',
        queryParameters: {'q': userId.toString(), 'limit': 50},
      );
      
      final List<dynamic> data = response.data;
      for (var userData in data) {
        final user = UserSearchModel.fromJson(userData);
        if (user.id == userId) {
          print('Found user: ${user.username}');
          return user;
        }
      }
      
      // Если не нашли, возвращаем заглушку
      return UserSearchModel(
        id: userId,
        username: 'Пользователь #$userId',
        email: '',
        isActive: true,
      );
    } catch (e) {
      print('Error searching user by ID $userId: $e');
      return UserSearchModel(
        id: userId,
        username: 'Пользователь #$userId',
        email: '',
        isActive: true,
      );
    }
  }
  */

  // Отправить заявку в друзья
  Future<void> sendFriendRequest(int friendId) async {
    try {
      await DioClient.post('/friends/requests', data: {
        'friend_id': friendId,
      });
    } catch (e) {
      throw Exception('Ошибка отправки заявки: $e');
    }
  }

  // Получить ID пользователей, которые отправили заявку текущему пользователю
  Future<Set<int>> getIncomingRequestSenderIds() async {
    try {
      final requests = await getIncomingRequests();
      return requests.map((r) => r.userId).toSet();
    } catch (e) {
      return {};
    }
  }
  
  // Получить исходящие заявки (для проверки статуса)
  Future<List<FriendRequestModel>> getOutgoingRequests() async {
    try {
      final response = await DioClient.get('/friends/requests/outgoing');
      final List<dynamic> data = response.data;
      return data.map((json) => FriendRequestModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Ошибка загрузки исходящих заявок: $e');
    }
  }
}