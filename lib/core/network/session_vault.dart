import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Session secrets must never be stored in the general offline SQLite database.
abstract interface class SessionVault {
  Future<String?> read(String server);
  Future<void> write(String server, String value);
  Future<void> delete(String server);
}

class SecureSessionVault implements SessionVault {
  const SecureSessionVault();
  static const _storage = FlutterSecureStorage();
  String _key(String server) =>
      'asoud-session-v1:${Uri.encodeComponent(server)}';
  @override
  Future<String?> read(String server) => _storage.read(key: _key(server));
  @override
  Future<void> write(String server, String value) =>
      _storage.write(key: _key(server), value: value);
  @override
  Future<void> delete(String server) => _storage.delete(key: _key(server));
}
