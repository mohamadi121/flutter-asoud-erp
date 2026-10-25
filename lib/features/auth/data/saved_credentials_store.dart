import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal key/value surface of the OS secure store (Keychain / Keystore).
/// Tests inject a memory implementation; production uses
/// [SecureCredentialVault].
abstract interface class CredentialVault {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureCredentialVault implements CredentialVault {
  const SecureCredentialVault();
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Remembers the last server and username, and, only when the user ticked
/// «ذخیره رمز عبور در این دستگاه», the password of one server+username pair.
///
/// Rules (spec section 1):
/// * the password lives only in the OS secure store, never in
///   SharedPreferences, local storage, files or the offline database;
/// * on the web the app stores no password at all: the browser's own password
///   manager is used through autofill hints instead;
/// * every server+username pair is independent;
/// * signing out never calls [deletePassword]; only the user, a stale-password
///   login failure or a password change does.
class SavedCredentialsStore {
  SavedCredentialsStore({CredentialVault? vault, bool? isWeb})
      : _vault = vault ?? const SecureCredentialVault(),
        _isWeb = isWeb ?? kIsWeb;

  final CredentialVault _vault;
  final bool _isWeb;

  static const _lastServerKey = 'asoud-login-last-server-v1';

  /// Native apps can keep a password in the secure store; the web cannot.
  bool get canStorePassword => !_isWeb;

  static String _pair(String prefix, String server, String username) =>
      '$prefix:${Uri.encodeComponent(jsonEncode([
            server.trim().toLowerCase(),
            username.trim().toLowerCase()
          ]))}';

  static String _passwordKey(String server, String username) =>
      _pair('asoud-login-password-v1', server, username);

  static String _lastUserKey(String server) =>
      'asoud-login-last-user-v1:${Uri.encodeComponent(server.trim().toLowerCase())}';

  Future<T?> _guard<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(const Duration(seconds: 4));
    } catch (_) {
      return null;
    }
  }

  Future<String?> lastServer() => _guard<String?>(() => _vault.read(_lastServerKey));

  Future<void> rememberServer(String server) =>
      _guard(() => _vault.write(_lastServerKey, server)).then((_) {});

  Future<String?> lastUsername(String server) =>
      _guard<String?>(() => _vault.read(_lastUserKey(server)));

  Future<void> rememberUsername(String server, String username) async {
    final name = username.trim();
    if (name.isEmpty) {
      await _guard(() => _vault.delete(_lastUserKey(server)));
    } else {
      await _guard(() => _vault.write(_lastUserKey(server), name));
    }
  }

  Future<void> forgetUsername(String server) =>
      _guard(() => _vault.delete(_lastUserKey(server))).then((_) {});

  Future<String?> readPassword(String server, String username) async {
    if (!canStorePassword || username.trim().isEmpty) return null;
    final value = await _guard<String?>(
        () => _vault.read(_passwordKey(server, username)));
    return value == null || value.isEmpty ? null : value;
  }

  Future<bool> hasPassword(String server, String username) async =>
      await readPassword(server, username) != null;

  /// Returns true only when the OS store confirmed the write, so the checkbox
  /// is never reported as active when nothing was saved.
  Future<bool> savePassword(
      String server, String username, String password) async {
    if (!canStorePassword || username.trim().isEmpty || password.isEmpty) {
      return false;
    }
    final key = _passwordKey(server, username);
    try {
      await _vault.write(key, password).timeout(const Duration(seconds: 4));
      return await _vault.read(key).timeout(const Duration(seconds: 4)) ==
          password;
    } catch (_) {
      return false;
    }
  }

  Future<void> deletePassword(String server, String username) async {
    if (username.trim().isEmpty) return;
    await _guard(() => _vault.delete(_passwordKey(server, username)));
  }
}

/// In-memory vault for tests and previews. Never used in production.
class MemoryCredentialVault implements CredentialVault {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}
