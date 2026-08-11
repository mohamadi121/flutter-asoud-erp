import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class OfflineMutationStore {
  OfflineMutationStore._();
  static final instance = OfflineMutationStore._();
  static const _key = 'asoud_offline_mutations_v1';

  Future<String> stage({
    required String operation,
    required String target,
    required Map<String, dynamic> payload,
  }) async {
    final id = '${DateTime.now().microsecondsSinceEpoch}-$operation';
    final items = await pending();
    items.add({
      'id': id,
      'operation': operation,
      'target': target,
      'payload': _safePayload(payload),
      'created_at': DateTime.now().toIso8601String(),
      'status': 'staged',
    });
    await _write(items);
    return id;
  }

  Future<void> markPending(String id) async {
    final items = await pending();
    for (final item in items) {
      if (item['id'] == id) item['status'] = 'pending_sync';
    }
    await _write(items);
  }

  Future<void> remove(String id) async {
    final items = await pending();
    items.removeWhere((item) => item['id'] == id);
    await _write(items);
  }

  Future<List<Map<String, dynamic>>> pending() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List
          ? decoded
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : [];
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<Map<String, dynamic>> items) async {
    await (await SharedPreferences.getInstance())
        .setString(_key, jsonEncode(items));
  }

  Map<String, dynamic> _safePayload(Map<String, dynamic> payload) {
    final copy = Map<String, dynamic>.from(payload);
    for (final key in copy.keys.toList()) {
      final value = copy[key];
      if (key.toLowerCase().contains('password')) {
        copy[key] = '[محافظت‌شده]';
      } else if (value is String && value.length > 500000) {
        copy[key] = '[فایل بزرگ؛ در حافظه فایل برنامه نگهداری شود]';
      }
    }
    return copy;
  }
}
