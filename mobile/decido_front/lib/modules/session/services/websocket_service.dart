import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_config.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../config/env/env_config.dart';
import '../models/session_models.dart';
import '../../../main.dart';

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
  bool _isConnecting = false;
  bool _isConnected = false;
  
  
  bool get isGlobalConnected => _globalChannel != null;
  bool get isConnected => _isConnected && _channel != null;
  int? get currentSessionId => _currentSessionId;


  Future<void> connect(int sessionId) async {
    print('🟢 [WS CONNECT] Starting connection to session $sessionId');
    print('   Current state: _currentSessionId=$_currentSessionId, _isConnected=$_isConnected, _isConnecting=$_isConnecting');
    
    // Если уже подключены к этой сессии, ничего не делаем
    if (_currentSessionId == sessionId && _isConnected && _channel != null) {
      print('🟢 [WS CONNECT] Already connected to session $sessionId, skipping');
      return;
    }
    
    // Если уже идет подключение к этой сессии, не начинаем новое
    if (_isConnecting && _currentSessionId == sessionId) {
      print('🟢 [WS CONNECT] Already connecting to session $sessionId, skipping');
      return;
    }
    
    // Если подключены к другой сессии, отключаемся
    if (_channel != null && _currentSessionId != sessionId) {
      print('🟢 [WS CONNECT] Disconnecting from different session $_currentSessionId');
      await disconnect();
    }
    
    _isConnecting = true;
    _currentSessionId = sessionId;
    _isConnected = false;
    
    if (AppConfig.useMocks) {
      print('Mock WebSocket connected to session $sessionId');
      _startMockHeartbeat();
      _isConnected = true;
      _isConnecting = false;
      return;
    }
    
    final token = await SecureStorage.getAccessToken();
    if (token == null) {
      print('❌ [WS CONNECT] No token');
      _isConnecting = false;
      throw Exception('No token');
    }
    
    final wsUrl = '${EnvConfig.wsBaseUrl}/sessions/$sessionId/ws?token=Bearer $token';
    print('Connecting to WebSocket: $wsUrl');
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      _channel!.stream.listen(
        (data) {
          print('🟢 [WS] Data received, setting connected=true');
          _isConnected = true;
          _isConnecting = false;
          _handleMessage(data);
        },
        onError: (error) {
          print('🔴 [WS] Error: $error');
          _isConnected = false;
          _isConnecting = false;
        },
        onDone: () {
          print('🔴 [WS] Done (disconnected)');
          _isConnected = false;
          _isConnecting = false;
          _channel = null;
        },
      );
      
      print('🟢 [WS CONNECT] Connection initiated to session $sessionId');
    } catch (e) {
      print('WebSocket connection failed: $e');
      _isConnected = false;
      _isConnecting = false;
    }
  }

  Future<void> disconnect() async {
    print('🔴 [WS DISCONNECT] Called, current session: $_currentSessionId');
    _isConnected = false;
    _isConnecting = false;
    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
    }
    _mockTimer?.cancel();
    _mockTimer = null;
    // НЕ сбрасываем _currentSessionId здесь
  }

  // Добавьте отдельный метод для полного сброса
  Future<void> forceDisconnect() async {
    await disconnect();
    _currentSessionId = null;
    print('🔴 [WS FORCE DISCONNECT] Complete reset');
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

  // --- Остальные методы ---

  void sendMessage(String type, {Map<String, dynamic> payload = const {}}) {
    final message = WSMessage(type: type, payload: payload);
    
    if (AppConfig.useMocks) {
      _handleMockMessage(message);
      return;
    }
    
    if (_channel == null) {
      print('❌ Cannot send message: WebSocket not connected');
      return;
    }
    _channel!.sink.add(jsonEncode(message.toJson()));
  }

  void _handleMockMessage(WSMessage message) {
    print('Mock send: ${message.type}');
  }

  void _handleMessage(dynamic data) {
    print('------------ try _handleMessage');
    try {
      print('------------ try parsing WebSocket message');
      final json = jsonDecode(data);
      final message = WSMessage.fromJson(json);
      print('🔔 WebSocket message received: ${message.type}');
      print('🔔 Full message: ${message.payload}');
      
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
  void startVoting() => sendMessage(WSMessageType.startVoting);
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
  void unready() => sendMessage(WSMessageType.unready);
}