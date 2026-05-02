import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_config.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../config/env/env_config.dart';
import '../models/session_models.dart';
import '../../../main.dart';  // Импортируем main.dart для доступа к navigatorKey

class WebSocketService {
  static WebSocketService? _instance;
  static WebSocketService get instance {
    _instance ??= WebSocketService._();
    return _instance!;
  }
  
  WebSocketService._();
  
  WebSocketChannel? _channel;
  WebSocketChannel? _globalChannel;
  int? _currentSessionId;
  final List<Function(WSMessage)> _listeners = [];
  Timer? _mockTimer;
  
  bool get isConnected => _channel != null || AppConfig.useMocks;
  int? get currentSessionId => _currentSessionId;

  // --- Существующие методы ---
  
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
    
    final wsUrl = '${EnvConfig.wsBaseUrl}/sessions/$sessionId/ws?token=Bearer $token';
    print('Connecting to WebSocket: $wsUrl');
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      _channel!.stream.listen(
        (data) => _handleMessage(data),
        onError: (error) => print('WebSocket error: $error'),
        onDone: () => print('WebSocket disconnected'),
      );
      
      print('WebSocket connected to session $sessionId');
    } catch (e) {
      print('WebSocket connection failed: $e');
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

  // --- Глобальное соединение ---

  Future<void> connectGlobal() async {
    if (_globalChannel != null) {
      print('Global WebSocket already connected');
      return;
    }
    
    await _disconnectGlobal();
    
    if (AppConfig.useMocks) {
      print('Mock Global WebSocket connected');
      return;
    }
    
    final token = await SecureStorage.getAccessToken();
    if (token == null) {
      print('No token for global WebSocket');
      return;
    }
    
    final wsUrl = '${EnvConfig.wsBaseUrl}/global?token=Bearer $token';
    print('Connecting to Global WebSocket: $wsUrl');
    
    try {
      _globalChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      _globalChannel!.stream.listen(
        (data) => _handleGlobalMessage(data),
        onError: (error) => print('Global WebSocket error: $error'),
        onDone: () => print('Global WebSocket disconnected'),
      );
      print('Global WebSocket connected');
    } catch (e) {
      print('Global WebSocket failed: $e');
    }
  }
  
  Future<void> _disconnectGlobal() async {
    if (_globalChannel != null) {
      await _globalChannel!.sink.close();
      _globalChannel = null;
    }
  }

  void _handleGlobalMessage(dynamic data) {
    print('🔔 _handleGlobalMessage called with: $data');
    try {
      final json = jsonDecode(data);
      print('🔔 Decoded JSON: $json');
      final message = WSMessage.fromJson(json);
      print('🔔 Global message type: ${message.type}');
      
      if (message.type == WSMessageType.NAVIGATE_TO_LOBBY) {
        final sessionId = message.payload['session_id'];
        print('🔔 Navigating to lobby: $sessionId');
        final context = navigatorKey.currentContext;
        if (context != null) {
          GoRouter.of(context).pushReplacement('/session/$sessionId');
        } else {
          print('❌ navigatorKey.currentContext is null!');
        }
      }
    } catch (e) {
      print('❌ Error parsing global message: $e');
    }
  }

  // --- Остальные методы без изменений ---

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