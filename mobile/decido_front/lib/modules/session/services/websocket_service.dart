import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../../../config/app_config.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../config/env/env_config.dart';
import '../models/session_models.dart';
import '../../../config/app_config.dart';

class WebSocketService {
  static WebSocketService? _instance;
  static WebSocketService get instance {
    _instance ??= WebSocketService._();
    return _instance!;
  }
  
  WebSocketService._();
  
  WebSocketChannel? _channel;
  int? _currentSessionId;
  final List<Function(WSMessage)> _listeners = [];
  Timer? _mockTimer;
  
  bool get isConnected => _channel != null || AppConfig.useMocks;
  int? get currentSessionId => _currentSessionId;
  
  /// Подключиться к WebSocket лобби
  Future<void> connect(int sessionId) async {
    await disconnect();
    _currentSessionId = sessionId;
    
    if (AppConfig.useMocks) {
      // Мок-режим - имитируем подключение
      print('Mock WebSocket connected to session $sessionId');
      _startMockHeartbeat();
      return;
    }
    
    final token = await SecureStorage.getAccessToken();
    if (token == null) throw Exception('No token');
    
    final wsUrl = '${EnvConfig.wsBaseUrl}/sessions/$sessionId/ws';
    _channel = IOWebSocketChannel.connect(
      Uri.parse(wsUrl),
      headers: {'Authorization': 'Bearer $token'},
    );
    
    _channel!.stream.listen(
      (data) => _handleMessage(data),
      onError: (error) => print('WebSocket error: $error'),
      onDone: () => print('WebSocket disconnected'),
    );
    
    print('WebSocket connected to session $sessionId');
  }
  
  void _startMockHeartbeat() {
    _mockTimer?.cancel();
    _mockTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      // Имитация ping/pong
    });
  }
  
  /// Отключиться
  Future<void> disconnect() async {
    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
    }
    _mockTimer?.cancel();
    _mockTimer = null;
    _currentSessionId = null;
  }
  
  /// Отправить сообщение
  void sendMessage(String type, {Map<String, dynamic> payload = const {}}) {
    final message = WSMessage(type: type, payload: payload);
    
    if (AppConfig.useMocks) {
      _handleMockMessage(message);
      return;
    }
    
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode(message.toJson()));
  }
  
    void _handleMockMessage(WSMessage message) {
    print('Mock send: ${message.type}');
    
    switch (message.type) {
      case WSMessageType.ready:
        Future.delayed(const Duration(milliseconds: 300), () {
          _notifyListeners(WSMessage(
            type: WSMessageType.participantReady,
            payload: {'user_id': 1, 'username': 'Я (Хост)'},
          ));
        });
        break;
        
      case WSMessageType.startLobby:
        print('Mock: Starting lobby, will notify voting_started');
        
        // Сначала отправляем state_changed для обновления сессии
        _notifyListeners(WSMessage(
          type: WSMessageType.stateChanged,
          payload: {},
        ));
        
        // Затем через задержку отправляем voting_started
        Future.delayed(const Duration(milliseconds: 500), () async {
          // Принудительно обновляем статус в мок-хранилище
          await _updateSessionStatusToVoting();
          
          _notifyListeners(WSMessage(
            type: WSMessageType.votingStarted,
            payload: {'voting_ends_at': DateTime.now().add(const Duration(seconds: 120)).toIso8601String()},
          ));
        });
        break;
        
      case WSMessageType.vote:
        print('Mock: Vote received');
        Future.delayed(const Duration(milliseconds: 300), () async {
          // Обновляем статус сессии на results
          await _updateSessionStatusToResults();
          
          _notifyListeners(WSMessage(
            type: WSMessageType.resultsReady,
            payload: {},
          ));
        });
        break;
        
      case WSMessageType.addItem:
      case WSMessageType.updateItem:
      case WSMessageType.deleteItem:
      case WSMessageType.updateOrder:
        _notifyListeners(WSMessage(
          type: WSMessageType.stateChanged,
          payload: {},
        ));
        break;
        
      case WSMessageType.leaveLobby:
      case WSMessageType.closeLobby:
        _notifyListeners(WSMessage(
          type: WSMessageType.lobbyClosed,
          payload: {'session_id': _currentSessionId},
        ));
        break;
    }
  }
  
  Future<void> _updateSessionStatusToResults() async {
    if (_currentSessionId == null) return;
    
    final sessionData = AppConfig.getSession(_currentSessionId!);
    if (sessionData != null) {
      // Вычисляем результаты
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
      
      sessionData['status'] = 'results';
      sessionData['results'] = {
        'session_id': _currentSessionId,
        'winner': resultsList.first,
        'results': resultsList,
        'participants_count': participants.length,
        'voted_count': votedCount,
      };
      sessionData['voting_ends_at'] = null;
      AppConfig.updateSession(_currentSessionId!, sessionData);
    }
  }


  Future<void> _updateSessionStatusToVoting() async {
    if (_currentSessionId == null) return;
    
    final sessionData = AppConfig.getSession(_currentSessionId!);
    if (sessionData != null) {
      sessionData['status'] = 'voting';
      sessionData['voting_ends_at'] = DateTime.now().add(
        const Duration(seconds: 120),
      ).toIso8601String();
      AppConfig.updateSession(_currentSessionId!, sessionData);
    }
  }
  
  void _notifyListeners(WSMessage message) {
    for (final listener in _listeners) {
      listener(message);
    }
  }
  
  void addListener(Function(WSMessage) listener) {
    _listeners.add(listener);
  }
  
  void removeListener(Function(WSMessage) listener) {
    _listeners.remove(listener);
  }
  
  void _handleMessage(dynamic data) {
    try {
      final json = jsonDecode(data);
      final message = WSMessage.fromJson(json);
      for (final listener in _listeners) {
        listener(message);
      }
    } catch (e) {
      print('Error parsing WebSocket message: $e');
    }
  }
  
  // ============= Удобные методы отправки =============
  void sendPing() => sendMessage(WSMessageType.ping);
  void acceptInvite() => sendMessage(WSMessageType.acceptInvite);
  void declineInvite() => sendMessage(WSMessageType.declineInvite);
  void markReady() => sendMessage(WSMessageType.ready);
  void startLobby() => sendMessage(WSMessageType.startLobby);
  void changeList(int listId) => sendMessage(WSMessageType.changeList, payload: {'list_id': listId});
  void kickParticipant(int userId) {
    sendMessage('kick_participant', payload: {'user_id': userId});
  }
  void lockList() => sendMessage(WSMessageType.lockList);
  void unlockList() => sendMessage(WSMessageType.unlockList);
  void addItem(String name, {String? description, String? imageUrl}) => sendMessage(
    WSMessageType.addItem,
    payload: {'name': name, 'description': description, 'image_url': imageUrl},
  );
  void updateItem(int itemId, {String? name, String? description, String? imageUrl}) => sendMessage(
    WSMessageType.updateItem,
    payload: {'item_id': itemId, 'name': name, 'description': description, 'image_url': imageUrl},
  );
  void deleteItem(int itemId) => sendMessage(WSMessageType.deleteItem, payload: {'item_id': itemId});
  void updateOrder(List<Map<String, int>> items) => sendMessage(WSMessageType.updateOrder, payload: {'items': items});
  void submitVote({List<int>? rankedItemIds, bool spin = false}) => sendMessage(
    WSMessageType.vote,
    payload: {'ranked_item_ids': rankedItemIds, 'spin': spin},
  );
  void leaveLobby() => sendMessage(WSMessageType.leaveLobby);
  void closeLobby() => sendMessage(WSMessageType.closeLobby);
  void backToLobby() => sendMessage(WSMessageType.backToLobby);
}