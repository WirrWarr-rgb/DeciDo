

class AppConfig {
  // Режим работы: true - использовать моки, false - реальный бэкенд
  static bool useMocks = true;
  
  // Задержка для имитации сетевых запросов (мс)
  static const int mockDelay = 500;
  
  // Данные для мок-авторизации
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
      'avatar_url': null,
    },
  };
  
  static Map<String, Map<String, dynamic>> get users => _users;
  
  static void addUser(String username, String email, String password) {
    _users[username] = {
      'id': _users.length + 1,
      'username': username,
      'email': email,
      'password': password,
      'avatar_url': null,
    };
  }
  
  static bool isUsernameExists(String username) {
    return _users.containsKey(username);
  }
  
  static bool isEmailExists(String email) {
    return _users.values.any((user) => user['email'] == email);
  }
}