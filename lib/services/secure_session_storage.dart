import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uses Android Keystore / iOS Keychain through the platform plugin.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage(this.projectHost);
  final String projectHost;
  final _storage = const FlutterSecureStorage();
  String get _key => 'pass-the-spark-session-$projectHost';

  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: _key);
  @override
  Future<String?> accessToken() => _storage.read(key: _key);
  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _key, value: persistSessionString);
  @override
  Future<void> removePersistedSession() => _storage.delete(key: _key);
}

class SecurePkceStorage extends GotrueAsyncStorage {
  final _storage = const FlutterSecureStorage();
  @override
  Future<String?> getItem({required String key}) =>
      _storage.read(key: 'spark-pkce-$key');
  @override
  Future<void> setItem({required String key, required String value}) =>
      _storage.write(key: 'spark-pkce-$key', value: value);
  @override
  Future<void> removeItem({required String key}) =>
      _storage.delete(key: 'spark-pkce-$key');
}
