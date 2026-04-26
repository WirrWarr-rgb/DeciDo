import 'dart:async';
import '../../../config/app_config.dart';
import '../models/session_models.dart';
import 'i_session_repository.dart';

class MockSessionRepository implements ISessionRepository {
  // Текущий пользователь (для моков)
  static int currentUserId = 1;
  static String currentUsername = 'Я (Хост)';
  
  // Мок-данные для друзей (для получения имён)
  static final List<Map<String, dynamic>> _mockFriends = [
    {'id': 2, 'username': 'Анна', 'email': 'anna@example.com'},
    {'id': 3, 'username': 'Дмитрий', 'email': 'dmitry@example.com'},
    {'id': 4, 'username': 'Елена', 'email': 'elena@example.com'},
    {'id': 5, 'username': 'Максим', 'email': 'maxim@example.com'},
    {'id': 6, 'username': 'Ольга', 'email': 'olga@example.com'},
  ];
  
  // Создать лобби
  @override
  Future<SessionModel> createLobby(CreateLobbyRequest request) async {
    await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay));
    
    final sessionId = AppConfig.generateSessionId();
    final now = DateTime.now();
    
    // Создаем список из мок-элементов
    final items = [
      SessionListItemModel(
        id: 101,
        name: 'Пицца',
        description: 'Итальянская пицца с различными топпингами',
        orderIndex: 0,
      ),
      SessionListItemModel(
        id: 102,
        name: 'Суши',
        description: 'Японские роллы с лососем и авокадо',
        orderIndex: 1,
      ),
      SessionListItemModel(
        id: 103,
        name: 'Бургер',
        description: 'Сочный бургер с говяжьей котлетой',
        orderIndex: 2,
      ),
      SessionListItemModel(
        id: 104,
        name: 'Паста',
        description: 'Паста Карбонара с беконом и пармезаном',
        orderIndex: 3,
      ),
      SessionListItemModel(
        id: 105,
        name: 'Салат',
        description: 'Свежий овощной салат с оливковым маслом',
        orderIndex: 4,
      ),
    ];
    
    final sessionList = SessionListModel(
      id: 1,
      name: 'Что заказываем?',
      isActive: true,
      items: items,
      createdAt: now,
    );
    
    // Создаем участников
    final participants = <ParticipantModel>[
      ParticipantModel(
        userId: currentUserId,
        username: currentUsername,
        status: ParticipantStatus.accepted,
        isReady: false,
        hasVoted: false,
        isOwner: true,
        invitedAt: now,
        joinedAt: now,
      ),
    ];
    
    // Добавляем приглашенных друзей с реальными именами
    for (var friendId in request.friendIds) {
      final friend = _mockFriends.firstWhere(
        (f) => f['id'] == friendId,
        orElse: () => {'id': friendId, 'username': 'Друг $friendId', 'email': ''},
      );
      
      participants.add(
        ParticipantModel(
          userId: friendId,
          username: friend['username'] as String,
          status: ParticipantStatus.accepted,
          isReady: false,
          hasVoted: false,
          isOwner: false,
          invitedAt: now,
          joinedAt: now,
        ),
      );
    }
    
    final session = SessionModel(
      id: sessionId,
      ownerId: currentUserId,
      ownerName: currentUsername,
      status: SessionStatus.editing,
      mode: request.mode,
      listLocked: false,
      currentList: sessionList,
      participants: participants,
      votingDuration: request.votingDuration,
      createdAt: now,
      isOwner: true,
      canEditList: true,
      canStart: true,
      canInvite: true,
      canLockList: true,
    );
    
    // Сохраняем в мок-хранилище
    AppConfig.addSession(_sessionToMap(session));
    
    return session;
  }
  
  // Получить лобби
  @override
  Future<SessionModel> getLobby(int sessionId) async {
    await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay ~/ 2));
    
    final sessionData = AppConfig.getSession(sessionId);
    if (sessionData == null) {
      throw Exception('Лобби не найдено');
    }
    
    return _mapToSession(sessionData);
  }
  
  // Отметить готовность
  @override
  Future<void> markReady(int sessionId) async {
    await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay ~/ 2));
    
    final sessionData = AppConfig.getSession(sessionId);
    if (sessionData == null) throw Exception('Лобби не найдено');
    
    final participants = List<Map<String, dynamic>>.from(sessionData['participants']);
    final participantIndex = participants.indexWhere((p) => p['user_id'] == currentUserId);
    
    if (participantIndex != -1) {
      participants[participantIndex]['is_ready'] = !participants[participantIndex]['is_ready'];
      sessionData['participants'] = participants;
      AppConfig.updateSession(sessionId, sessionData);
    }
  }
  
  // Принудительно начать
  @override
  Future<void> forceStart(int sessionId) async {
    await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay));
    
    final sessionData = AppConfig.getSession(sessionId);
    if (sessionData == null) throw Exception('Лобби не найдено');
    
    // Обновляем статус сессии на voting
    sessionData['status'] = 'voting';
    sessionData['voting_ends_at'] = DateTime.now().add(
      Duration(seconds: sessionData['voting_duration']),
    ).toIso8601String();
    
    AppConfig.updateSession(sessionId, sessionData);
    
    // Отправляем уведомление о начале голосования через WebSocket
    await Future.delayed(const Duration(milliseconds: 100));
  }
  
  
  @override
  Future<Map<String, dynamic>> submitVote(
    int sessionId, {
    List<int>? rankedItemIds,
    bool spin = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay));
    
    final sessionData = AppConfig.getSession(sessionId);
    if (sessionData == null) throw Exception('Лобби не найдено');
    
    final participants = List<Map<String, dynamic>>.from(sessionData['participants']);
    final participantIndex = participants.indexWhere((p) => p['user_id'] == currentUserId);
    
    if (participantIndex != -1) {
      participants[participantIndex]['has_voted'] = true;
      participants[participantIndex]['vote_data'] = {'ranked_ids': rankedItemIds};
      sessionData['participants'] = participants;
      AppConfig.updateSession(sessionId, sessionData);
    }
    
    // В мок-режиме сразу вычисляем результаты и переводим сессию в статус results
    final results = await _calculateResults(sessionId, sessionData);
    sessionData['status'] = 'results';
    sessionData['results'] = results;
    sessionData['voting_ends_at'] = null;
    AppConfig.updateSession(sessionId, sessionData);
    
    return {'success': true, 'message': 'Vote submitted', 'all_voted': true};
  }

  // Добавь метод _calculateResults:
  Future<Map<String, dynamic>> _calculateResults(int sessionId, Map<String, dynamic> sessionData) async {
    final items = List<Map<String, dynamic>>.from(sessionData['current_list']['items']);
    final participants = List<Map<String, dynamic>>.from(sessionData['participants']);
    final scores = <int, int>{};
    
    for (var item in items) {
      scores[item['id']] = 0;
    }
    
    int votedCount = 0;
    for (var p in participants) {
      if (p['has_voted'] == true && p['vote_data'] != null) {
        votedCount++;
        final rankedIds = List<int>.from(p['vote_data']['ranked_ids']);
        for (var i = 0; i < rankedIds.length; i++) {
          scores[rankedIds[i]] = scores[rankedIds[i]]! + (items.length - i);
        }
      }
    }
    
    final sorted = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    
    final resultsList = <Map<String, dynamic>>[];
    for (var i = 0; i < sorted.length; i++) {
      final item = items.firstWhere((it) => it['id'] == sorted[i].key);
      resultsList.add({
        'item_id': sorted[i].key,
        'item_name': item['name'],
        'total_score': sorted[i].value,
        'place': i + 1,
      });
    }
    
    return {
      'session_id': sessionId,
      'winner': resultsList.first,
      'results': resultsList,
      'participants_count': participants.length,
      'voted_count': votedCount,
    };
  }

  // Получить результаты
  @override
  Future<Map<String, dynamic>> getResults(int sessionId) async {
    await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay ~/ 2));
    
    final sessionData = AppConfig.getSession(sessionId);
    if (sessionData == null) throw Exception('Результаты не найдены');
    
    if (sessionData['results'] == null) {
      throw Exception('Результаты ещё не готовы');
    }
    
    return sessionData['results'];
  }
  
  // Выйти из лобби
  @override
  Future<void> leaveLobby(int sessionId) async {
    await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay ~/ 2));
    AppConfig.deleteSession(sessionId);
  }
  
  // Закрыть лобби
  @override
  Future<void> closeLobby(int sessionId) async {
    await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay ~/ 2));
    AppConfig.deleteSession(sessionId);
  }
  
  // Вернуться в лобби после результатов
  @override
  Future<void> backToLobby(int sessionId) async {
    await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay));
    
    final sessionData = AppConfig.getSession(sessionId);
    if (sessionData == null) throw Exception('Лобби не найдено');
    
    sessionData['status'] = 'editing';
    sessionData['voting_ends_at'] = null;
    sessionData['results'] = null;
    
    final participants = List<Map<String, dynamic>>.from(sessionData['participants']);
    for (var p in participants) {
      p['is_ready'] = false;
      p['has_voted'] = false;
      p['vote_data'] = null;
    }
    sessionData['participants'] = participants;
    
    AppConfig.updateSession(sessionId, sessionData);
  }
  
  // Добавить элемент
  @override
  Future<SessionListItemModel> addItem(int sessionId, {
    required String name,
    String? description,
    String? imageUrl,
  }) async {
    await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay ~/ 2));
    
    final sessionData = AppConfig.getSession(sessionId);
    if (sessionData == null) throw Exception('Лобби не найдено');
    
    final items = List<Map<String, dynamic>>.from(sessionData['current_list']['items']);
    final newItemId = AppConfig.generateItemId();
    
    final newItem = {
      'id': newItemId,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'order_index': items.length,
    };
    
    items.add(newItem);
    sessionData['current_list']['items'] = items;
    AppConfig.updateSession(sessionId, sessionData);
    
    return _mapToItem(newItem);
  }
  
  // Обновить элемент
  @override
  Future<SessionListItemModel> updateItem(int sessionId, int itemId, {
    String? name,
    String? description,
    String? imageUrl,
  }) async {
    await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay ~/ 2));
    
    final sessionData = AppConfig.getSession(sessionId);
    if (sessionData == null) throw Exception('Лобби не найдено');
    
    final items = List<Map<String, dynamic>>.from(sessionData['current_list']['items']);
    final index = items.indexWhere((i) => i['id'] == itemId);
    
    if (index != -1) {
      if (name != null) items[index]['name'] = name;
      if (description != null) items[index]['description'] = description;
      if (imageUrl != null) items[index]['image_url'] = imageUrl;
      sessionData['current_list']['items'] = items;
      AppConfig.updateSession(sessionId, sessionData);
    }
    
    return _mapToItem(items[index]);
  }
  
  // Удалить элемент
  @override
  Future<void> deleteItem(int sessionId, int itemId) async {
    await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay ~/ 2));
    
    final sessionData = AppConfig.getSession(sessionId);
    if (sessionData == null) throw Exception('Лобби не найдено');
    
    final items = List<Map<String, dynamic>>.from(sessionData['current_list']['items']);
    items.removeWhere((i) => i['id'] == itemId);
    
    for (var i = 0; i < items.length; i++) {
      items[i]['order_index'] = i;
    }
    
    sessionData['current_list']['items'] = items;
    AppConfig.updateSession(sessionId, sessionData);
  }
  
  // Обновить порядок элементов
  @override
  Future<void> updateOrder(int sessionId, List<Map<String, int>> itemsOrder) async {
    await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay ~/ 2));
    
    final sessionData = AppConfig.getSession(sessionId);
    if (sessionData == null) throw Exception('Лобби не найдено');
    
    final items = List<Map<String, dynamic>>.from(sessionData['current_list']['items']);
    
    for (var order in itemsOrder) {
      final index = items.indexWhere((i) => i['id'] == order['id']);
      if (index != -1) {
        items[index]['order_index'] = order['order_index'];
      }
    }
    
    items.sort((a, b) => (a['order_index'] as int).compareTo(b['order_index'] as int));
    sessionData['current_list']['items'] = items;
    AppConfig.updateSession(sessionId, sessionData);
  }
  
  // Выгнать участника
  @override
  Future<void> kickParticipant(int sessionId, int userId) async {
    await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay ~/ 2));
    final sessionData = AppConfig.getSession(sessionId);
    if (sessionData == null) throw Exception('Лобби не найдено');
    
    final participants = List<Map<String, dynamic>>.from(sessionData['participants']);
    participants.removeWhere((p) => p['user_id'] == userId);
    sessionData['participants'] = participants;
    AppConfig.updateSession(sessionId, sessionData);
  }
  
  // Пригласить друзей
  @override
  Future<void> inviteFriends(int sessionId, List<int> friendIds) async {
    await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay ~/ 2));
    final sessionData = AppConfig.getSession(sessionId);
    if (sessionData == null) throw Exception('Лобби не найдено');
    
    final participants = List<Map<String, dynamic>>.from(sessionData['participants']);
    final now = DateTime.now();
    
    for (var friendId in friendIds) {
      if (!participants.any((p) => p['user_id'] == friendId)) {
        final friend = _mockFriends.firstWhere(
          (f) => f['id'] == friendId,
          orElse: () => {'id': friendId, 'username': 'Друг $friendId', 'email': ''},
        );
        
        participants.add({
          'user_id': friendId,
          'username': friend['username'],
          'status': 'invited',
          'is_ready': false,
          'has_voted': false,
          'is_owner': false,
          'invited_at': now.toIso8601String(),
        });
      }
    }
    sessionData['participants'] = participants;
    AppConfig.updateSession(sessionId, sessionData);
  }
  
  // Заблокировать список
  @override
  Future<void> lockList(int sessionId) async {
    await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay ~/ 2));
    final sessionData = AppConfig.getSession(sessionId);
    if (sessionData == null) throw Exception('Лобби не найдено');
    sessionData['list_locked'] = true;
    AppConfig.updateSession(sessionId, sessionData);
  }
  
  // Разблокировать список
  @override
  Future<void> unlockList(int sessionId) async {
    await Future.delayed(const Duration(milliseconds: AppConfig.mockDelay ~/ 2));
    final sessionData = AppConfig.getSession(sessionId);
    if (sessionData == null) throw Exception('Лобби не найдено');
    sessionData['list_locked'] = false;
    AppConfig.updateSession(sessionId, sessionData);
  }
  
  // ============= Вспомогательные методы =============
  
  Map<String, dynamic> _sessionToMap(SessionModel session) {
    return {
      'id': session.id,
      'owner_id': session.ownerId,
      'owner_name': session.ownerName,
      'status': session.status.value,
      'mode': session.mode.value,
      'list_locked': session.listLocked,
      'current_list': session.currentList != null ? _listToMap(session.currentList!) : null,
      'participants': session.participants.map((p) => _participantToMap(p)).toList(),
      'voting_duration': session.votingDuration,
      'created_at': session.createdAt.toIso8601String(),
      'voting_ends_at': session.votingEndsAt?.toIso8601String(),
      'results': session.results,
      'is_owner': session.isOwner,
      'can_edit_list': session.canEditList,
      'can_start': session.canStart,
      'can_invite': session.canInvite,
      'can_lock_list': session.canLockList,
    };
  }
  
  Map<String, dynamic> _listToMap(SessionListModel list) {
    return {
      'id': list.id,
      'name': list.name,
      'is_active': list.isActive,
      'items': list.items.map((i) => _itemToMap(i)).toList(),
      'created_at': list.createdAt.toIso8601String(),
    };
  }
  
  Map<String, dynamic> _itemToMap(SessionListItemModel item) {
    return {
      'id': item.id,
      'name': item.name,
      'description': item.description,
      'image_url': item.imageUrl,
      'order_index': item.orderIndex,
      'created_by': item.createdBy,
      'creator_name': item.creatorName,
    };
  }
  
  Map<String, dynamic> _participantToMap(ParticipantModel participant) {
    return {
      'user_id': participant.userId,
      'username': participant.username,
      'status': participant.status.value,
      'is_ready': participant.isReady,
      'has_voted': participant.hasVoted,
      'is_owner': participant.isOwner,
      'invited_at': participant.invitedAt.toIso8601String(),
      'joined_at': participant.joinedAt?.toIso8601String(),
    };
  }
  
  SessionModel _mapToSession(Map<String, dynamic> map) {
    return SessionModel(
      id: map['id'],
      ownerId: map['owner_id'],
      ownerName: map['owner_name'],
      status: SessionStatus.fromString(map['status']),
      mode: SessionMode.fromString(map['mode']),
      listLocked: map['list_locked'],
      currentList: map['current_list'] != null ? _mapToList(map['current_list']) : null,
      participants: (map['participants'] as List).map((p) => _mapToParticipant(p)).toList(),
      votingDuration: map['voting_duration'],
      createdAt: DateTime.parse(map['created_at']),
      votingEndsAt: map['voting_ends_at'] != null ? DateTime.parse(map['voting_ends_at']) : null,
      results: map['results'],
      isOwner: map['is_owner'] ?? false,
      canEditList: map['can_edit_list'] ?? false,
      canStart: map['can_start'] ?? false,
      canInvite: map['can_invite'] ?? false,
      canLockList: map['can_lock_list'] ?? false,
    );
  }
  
  SessionListModel _mapToList(Map<String, dynamic> map) {
    return SessionListModel(
      id: map['id'],
      name: map['name'],
      isActive: map['is_active'],
      items: (map['items'] as List).map((i) => _mapToItem(i)).toList(),
      createdAt: DateTime.parse(map['created_at']),
    );
  }
  
  SessionListItemModel _mapToItem(Map<String, dynamic> map) {
    return SessionListItemModel(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      imageUrl: map['image_url'],
      orderIndex: map['order_index'],
      createdBy: map['created_by'],
      creatorName: map['creator_name'],
    );
  }
  
  ParticipantModel _mapToParticipant(Map<String, dynamic> map) {
    return ParticipantModel(
      userId: map['user_id'],
      username: map['username'],
      status: ParticipantStatus.fromString(map['status']),
      isReady: map['is_ready'],
      hasVoted: map['has_voted'],
      isOwner: map['is_owner'],
      invitedAt: DateTime.parse(map['invited_at']),
      joinedAt: map['joined_at'] != null ? DateTime.parse(map['joined_at']) : null,
    );
  }
}