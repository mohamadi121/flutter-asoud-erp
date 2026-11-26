import 'package:shared_preferences/shared_preferences.dart';

import '../network/frappe_client.dart';

/// Keep temporary delegation data in the delegated client's memory only.
class SessionPreferences {
  const SessionPreferences(this.client);

  final FrappeApiClient? client;

  bool get isolated => isPersonnelRepresentation(client);

  Future<String?> read(String key) async => isolated
      ? (await localStoreFor(client!).get('preference:$key'))?.payload['value']
          as String?
      : (await SharedPreferences.getInstance()).getString(key);

  Future<bool> write(String key, String value) async {
    if (!isolated) {
      return (await SharedPreferences.getInstance()).setString(key, value);
    }
    await localStoreFor(client!).save(
      id: 'preference:$key',
      entityType: 'session_preference',
      payload: {'value': value},
    );
    return true;
  }

  Future<void> remove(String key) async {
    if (isolated) {
      await localStoreFor(client!).delete('preference:$key');
    } else {
      await (await SharedPreferences.getInstance()).remove(key);
    }
  }
}
