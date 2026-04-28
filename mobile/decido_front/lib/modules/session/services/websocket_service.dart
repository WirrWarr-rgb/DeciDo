import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../config/app_config.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../config/env/env_config.dart';
import '../models/session_models.dart';

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

  Future<void> connect(int sessionId) async {
    await disconnect();
    _currentSessionId = sessionId;
    
    if (AppConfig.useMocks) {
      print('Mock WebSocket connected to session $sessionId');
      _startMockHeartbeat();
      return;
    }
    
    final token = await SecureStorage.getAccessToken();
    if (token == null) throw Exception('No token');
    
    // Формируем URL с токеном в query параметре (работает на всех платформах)
    final wsUrl = '${EnvConfig.wsBaseUrl}/sessions/$sessionId/ws?token=Bearer $token';
    print('Connecting to WebSocket: $wsUrl');
    
    try {
      // IOWebSocketChannel работает и на Web, и на Mobile
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      _channel!.stream.listen(
        (data) => _handleMessage(data),
        onError: (error) => print('WebSocket error: $error'),
        onDone: () => print('WebSocket disconnected'),
      );
      
      print('WebSocket connected to session $sessionId');
    } catch (e) {
      print('WebSocket connection failed: $e');
      // Не прерываем выполнение
    }
  }

  Future<void> disconnect() async {
    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
    }
    _mockTimer?.cancel();
    _mockTimer = null;
    _currentSessionId = null;
  }

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
    // ... остальной мок-код
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

  void addListener(Function(WSMessage) listener) {
    _listeners.add(listener);
  }

  void removeListener(Function(WSMessage) listener) {
    _listeners.remove(listener);
  }

  void _startMockHeartbeat() {
    _mockTimer?.cancel();
    _mockTimer = Timer.periodic(const Duration(seconds: 30), (timer) {});
  }

  // Удобные методы отправки
  void sendPing() => sendMessage(WSMessageType.ping);
  void acceptInvite() => sendMessage(WSMessageType.acceptInvite);
  void declineInvite() => sendMessage(WSMessageType.declineInvite);
  void markReady() => sendMessage(WSMessageType.ready);
  void startLobby() => sendMessage(WSMessageType.startLobby);
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