import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Режим работы: true - использовать моки, false - реальный бэкенд
  static bool useMocks = false;
  
  // Задержка для имитации сетевых запросов (мс)
  static const int mockDelay = 500;
  
  // Мок-данные для сессий
  static int _nextSessionId = 100;
  static int _nextItemId = 1000;

  // Базовый URL бэкенда
  static String get apiBaseUrl {
    return dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000/api/v1';
  }
  
  static String get wsBaseUrl {
    return dotenv.env['WS_BASE_URL'] ?? 'ws://localhost:8000/ws';
  }
  
  // Данные для мок-авторизации (оставляем для возможного переключения)
  static const String mockUsername = 'testuser';
  static const String mockEmail = 'test@example.com';
  static const String mockPassword = '123456';
  
  // Сохраненные пользователи (для имитации регистрации)
  static final Map<String, Map<String, dynamic>> _users = {
    'testuser': {
      'id': 1,
      'username': 'testuser',
      'email': 'test@example.com',
      'password': '123456',
      'is_active': true,
    },
  };
  
  static Map<String, Map<String, dynamic>> get users => _users;
  
  static void addUser(String username, String email, String password) {
    _users[username] = {
      'id': _users.length + 1,
      'username': username,
      'email': email,
      'password': password,
      'is_active': true,
    };
  }
  
  static bool isUsernameExists(String username) {
    return _users.containsKey(username);
  }
  
  static bool isEmailExists(String email) {
    return _users.values.any((user) => user['email'] == email);
  }


    // Мок-данные для сессий
  static final Map<int, Map<String, dynamic>> _sessions = {};
  
  static int generateSessionId() {
    return _nextSessionId++;
  }
  
  static int generateItemId() {
    return _nextItemId++;
  }
  
  static void addSession(Map<String, dynamic> session) {
    _sessions[session['id']] = session;
  }
  
  static Map<String, dynamic>? getSession(int sessionId) {
    return _sessions[sessionId];
  }
  
  static List<Map<String, dynamic>> getUserSessions(int userId) {
    return _sessions.values
        .where((s) => 
            s['owner_id'] == userId || 
            (s['participants'] as List).any((p) => p['user_id'] == userId))
        .toList();
  }
  
  static void updateSession(int sessionId, Map<String, dynamic> updates) {
    if (_sessions.containsKey(sessionId)) {
      _sessions[sessionId]!.addAll(updates);
    }
  }
  
  static void deleteSession(int sessionId) {
    _sessions.remove(sessionId);
  }
}