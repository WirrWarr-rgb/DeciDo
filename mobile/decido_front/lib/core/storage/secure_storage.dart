import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _accessTokenKey = 'access_token';
  static const _currentUserKey = 'current_user';
  
  // Настройка для Web
  static final FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
    webOptions: WebOptions(
      // Для Web используем localStorage
      // Важно: данные будут сохраняться после перезагрузки
    ),
  );
  
  static Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
    print('Token saved: $token'); // Для отладки
  }
  
  static Future<String?> getAccessToken() async {
    final token = await _storage.read(key: _accessTokenKey);
    print('Token retrieved: $token'); // Для отладки
    return token;
  }
  
  static Future<void> saveCurrentUser(String username) async {
    await _storage.write(key: _currentUserKey, value: username);
  }
  
  static Future<String?> getCurrentUser() async {
    return await _storage.read(key: _currentUserKey);
  }
  
  static Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _currentUserKey);
  }
}