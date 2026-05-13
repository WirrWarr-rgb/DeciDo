import 'package:dio/dio.dart';
import '../../../config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../models/friend_model.dart';
import '../models/friend_request_model.dart';
import '../models/user_search_model.dart';

class FriendsRepository {
  // Мок-данные для друзей
  static final List<FriendModel> _mockFriends = [
    FriendModel(id: 2, username: 'Анна', email: 'anna@example.com', isActive: true),
    FriendModel(id: 3, username: 'Дмитрий', email: 'dmitry@example.com', isActive: true),
    FriendModel(id: 4, username: 'Елена', email: 'elena@example.com', isActive: true),
    FriendModel(id: 5, username: 'Максим', email: 'maxim@example.com', isActive: true),
    FriendModel(id: 6, username: 'Ольга', email: 'olga@example.com', isActive: true),
  ];
  
  // Мок-пользователи для поиска
  static final List<UserSearchModel> _mockUsers = [
    UserSearchModel(id: 7, username: 'Иван', email: 'ivan@example.com', isActive: true),
    UserSearchModel(id: 8, username: 'Мария', email: 'maria@example.com', isActive: true),
    UserSearchModel(id: 9, username: 'Сергей', email: 'sergey@example.com', isActive: true),
    UserSearchModel(id: 10, username: 'Татьяна', email: 'tatiana@example.com', isActive: true),
  ];
  
  // Мок-заявки
  static List<FriendRequestModel> _mockIncomingRequests = [
    FriendRequestModel(
      id: 1,
      userId: 2,
      friendId: 1,
      status: FriendStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    FriendRequestModel(
      id: 2,
      userId: 3,
      friendId: 1,
      status: FriendStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];
  
  static List<FriendRequestModel> _mockOutgoingRequests = [
    FriendRequestModel(
      id: 3,
      userId: 1,
      friendId: 7,
      status: FriendStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];
  
  // Получить список друзей
  Future<List<FriendModel>> getFriends() async {
    if (AppConfig.useMocks) {
      await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay));
      return List.from(_mockFriends);
    }
    
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
    if (AppConfig.useMocks) {
      final friends = await getFriends();
      return friends.map((f) => f.id).toSet();
    }
    
    try {
      final friends = await getFriends();
      return friends.map((f) => f.id).toSet();
    } catch (e) {
      return {};
    }
  }
  
  // Удалить друга
  Future<void> removeFriend(int friendId) async {
    if (AppConfig.useMocks) {
      await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay));
      _mockFriends.removeWhere((f) => f.id == friendId);
      return;
    }
    
    try {
      await DioClient.delete('/friends/$friendId');
    } catch (e) {
      throw Exception('Ошибка удаления друга: $e');
    }
  }
  
  // Получить входящие заявки
  Future<List<FriendRequestModel>> getIncomingRequests() async {
    if (AppConfig.useMocks) {
      await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay));
      return List.from(_mockIncomingRequests);
    }
    
    try {
      final response = await DioClient.get('/friends/requests/incoming');
      final List<dynamic> data = response.data;
      return data.map((json) => FriendRequestModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Ошибка загрузки заявок: $e');
    }
  }
  
  // Получить исходящие заявки с данными получателей
  Future<List<Map<String, dynamic>>> getOutgoingRequestsWithUsers() async {
    if (AppConfig.useMocks) {
      await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay));
      final List<Map<String, dynamic>> result = [];
      
      for (final request in _mockOutgoingRequests) {
        final user = await getUserById(request.friendId);
        result.add({
          'request': request,
          'user': user,
        });
      }
      return result;
    }
    
    try {
      final requests = await getOutgoingRequests();
      final List<Map<String, dynamic>> result = [];
      
      for (final request in requests) {
        try {
          final user = await getUserById(request.friendId);
          result.add({
            'request': request,
            'user': user,
          });
        } catch (e) {
          result.add({
            'request': request,
            'user': UserSearchModel(
              id: request.friendId,
              username: 'Пользователь #${request.friendId}',
              email: '',
              isActive: true,
            ),
          });
        }
      }
      
      return result;
    } catch (e) {
      print('Error loading outgoing requests: $e');
      return [];
    }
  }
  
  // Принять заявку
  Future<void> acceptRequest(int requestId) async {
    if (AppConfig.useMocks) {
      await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay));
      
      final requestIndex = _mockIncomingRequests.indexWhere((r) => r.id == requestId);
      if (requestIndex != -1) {
        final request = _mockIncomingRequests[requestIndex];
        // Добавляем в друзья
        _mockFriends.add(FriendModel(
          id: request.userId,
          username: 'Пользователь #${request.userId}',
          email: '',
          isActive: false
        ));
        // Удаляем заявку
        _mockIncomingRequests.removeAt(requestIndex);
      }
      return;
    }
    
    try {
      await DioClient.put('/friends/requests/$requestId/accept');
    } catch (e) {
      throw Exception('Ошибка принятия заявки: $e');
    }
  }
  
  // Отклонить заявку
  Future<void> rejectRequest(int requestId) async {
    if (AppConfig.useMocks) {
      await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay));
      _mockIncomingRequests.removeWhere((r) => r.id == requestId);
      return;
    }
    
    try {
      await DioClient.put('/friends/requests/$requestId/reject');
    } catch (e) {
      throw Exception('Ошибка отклонения заявки: $e');
    }
  }
  
  // Поиск пользователей
  Future<List<UserSearchModel>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    
    if (AppConfig.useMocks) {
      await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay ~/ 2));
      
      final lowerQuery = query.toLowerCase();
      final allMockUsers = [
        ..._mockFriends.map((f) => UserSearchModel(
          id: f.id,
          username: f.username,
          email: f.email,
          isActive: true,
        )),
        ..._mockUsers,
      ];
      
      return allMockUsers
          .where((u) => u.username.toLowerCase().contains(lowerQuery))
          .toList();
    }
    
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

  // Получить пользователя по ID (прямой эндпоинт)
  Future<UserSearchModel> getUserById(int userId) async {
    if (AppConfig.useMocks) {
      await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay ~/ 2));
      
      // Ищем среди друзей
      final friend = _mockFriends.firstWhere(
        (f) => f.id == userId,
        orElse: () => FriendModel(id: -1, username: '', email: '', isActive: false),
      );
      
      if (friend.id != -1) {
        return UserSearchModel(
          id: friend.id,
          username: friend.username,
          email: friend.email,
          isActive: true,
        );
      }
      
      // Ищем среди других пользователей
      final user = _mockUsers.firstWhere(
        (u) => u.id == userId,
        orElse: () => UserSearchModel(id: -1, username: '', email: '', isActive: true),
      );
      
      if (user.id != -1) {
        return user;
      }
      
      return UserSearchModel(
        id: userId,
        username: 'Пользователь #$userId',
        email: '',
        isActive: true,
      );
    }
    
    try {
      final response = await DioClient.get('/users/$userId');
      return UserSearchModel.fromJson(response.data);
    } catch (e) {
      print('Error getting user by ID $userId: $e');
      return UserSearchModel(
        id: userId,
        username: 'Пользователь #$userId',
        email: '',
        isActive: true,
      );
    }
  }

  // Отправить заявку в друзья
  Future<void> sendFriendRequest(int friendId) async {
    if (AppConfig.useMocks) {
      await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay));
      // Добавляем в исходящие заявки
      _mockOutgoingRequests.add(
        FriendRequestModel(
          id: DateTime.now().millisecondsSinceEpoch,
          userId: 1,
          friendId: friendId,
          status: FriendStatus.pending,
          createdAt: DateTime.now(),
        ),
      );
      return;
    }
    
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
    if (AppConfig.useMocks) {
      final requests = await getIncomingRequests();
      return requests.map((r) => r.userId).toSet();
    }
    
    try {
      final requests = await getIncomingRequests();
      return requests.map((r) => r.userId).toSet();
    } catch (e) {
      return {};
    }
  }
  
  // Получить исходящие заявки (для проверки статуса)
  Future<List<FriendRequestModel>> getOutgoingRequests() async {
    if (AppConfig.useMocks) {
      await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay ~/ 2));
      return List.from(_mockOutgoingRequests);
    }
    
    try {
      final response = await DioClient.get('/friends/requests/outgoing');
      final List<dynamic> data = response.data;
      return data.map((json) => FriendRequestModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Ошибка загрузки исходящих заявок: $e');
    }
  }
}