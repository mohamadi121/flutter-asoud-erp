import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/frappe_client.dart';
import '../../../core/config/app_config.dart';

/// Wait configuration is an online validated write; drafts never schedule work.
class WorkflowWaitRepository {
  const WorkflowWaitRepository(this.client);
  final FrappeApiClient client;

  Future<Map<String, dynamic>> _call(String method, Map<String, dynamic> data) async {
    final response = await client.callMethod('asoud_erp.api.v1.workflow_wait.$method', data: data);
    final message = response['message'];
    if (message is! Map || message['ok'] != true || message['data'] is! Map) {
      throw StateError('پاسخ تنظیمات انتظار با نسخهٔ برنامه سازگار نیست.');
    }
    return Map<String, dynamic>.from(message['data'] as Map);
  }

  Future<Map<String, dynamic>> options(String definition, String stage) =>
      _call('get_wait_options', {'definition': definition, 'stage': stage});

  Future<void> save(String definition, String stage, Map<String, dynamic> config) async {
    await _call('save_wait_settings', {'definition': definition, 'stage': stage, 'config': config});
  }

  Future<String> _key(String definition, String stage) async {
    final user = client.isAuthenticated ? (await client.getCurrentUser()).userId : '__preview__';
    final server = client is FrappeClient ? (client as FrappeClient).serverIdentity : AppConfig.erpNextBaseUrl;
    return 'asoud_wait_v1_${base64Url.encode(utf8.encode(jsonEncode([server, user, definition, stage])))}';
  }

  Future<Map<String, dynamic>?> draft(String definition, String stage) async {
    final key = await _key(definition, stage);
    final raw = (await SharedPreferences.getInstance()).getString(key);
    return raw == null ? null : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> saveDraft(String definition, String stage, Map<String, dynamic> config) async {
    final key = await _key(definition, stage);
    if (!await (await SharedPreferences.getInstance()).setString(key, jsonEncode(config))) {
      throw StateError('ذخیرهٔ پیش‌نویس انتظار روی دستگاه انجام نشد.');
    }
  }

  Future<void> clearDraft(String definition, String stage) async {
    final key = await _key(definition, stage);
    await (await SharedPreferences.getInstance()).remove(key);
  }
}
