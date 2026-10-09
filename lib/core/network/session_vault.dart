import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Session secrets must never be stored in the general offline SQLite database.
abstract interface class SessionVault {
  Future<String?> read(String server);
  Future<void> write(String server, String value);
  Future<void> delete(String server);
}

/// The last selected server is not a credential. It is stored separately from
/// the server-scoped session so a new process can find the matching session.
abstract interface class ServerAddressStore {
  Future<String?> read();
  Future<void> write(String server);
}

class SecureServerAddressStore implements ServerAddressStore {
  const SecureServerAddressStore();
  static const _storage = FlutterSecureStorage();
  static const _key = 'asoud-last-server-v1';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String server) => _storage.write(key: _key, value: server);
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
