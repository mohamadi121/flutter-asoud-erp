import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../core/network/frappe_client.dart';
import '../../core/network/api_exception.dart';
import 'form_runtime/schema_migration.dart';

typedef FormMap = Map<String, dynamic>;
FormMap formMap(Object? value) =>
    Map<String, dynamic>.from(value as Map? ?? {});
List<FormMap> formMaps(Object? value) =>
    (value as List? ?? []).map(formMap).toList();
FormMap copyForm(FormMap value) => formMap(jsonDecode(jsonEncode(value)));
String newFormId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

class FormRepository {
  FormRepository(this.client, this.company);
  final FrappeApiClient client;
  final String company;
  String? _scope;
  static Future<void> _writes = Future<void>.value();
  Future<void> _persist(Future<void> Function() work) {
    final next = _writes.then((_) => work());
    _writes = next.catchError((Object _) {});
    return next;
  }

  Future<String> scope() async {
    final user = client.isAuthenticated
        ? (await client.getCurrentUser()).userId
        : '__local__';
    final server = client is FrappeClient
        ? (client as FrappeClient).serverIdentity
        : AppConfig.erpNextBaseUrl;
    final key =
        'asoud_forms_v1:${Uri.encodeComponent(server)}:${Uri.encodeComponent(user)}:${Uri.encodeComponent(company)}';
    if (_scope != null && _scope != key) {
      throw StateError('حساب یا سرور تغییر کرده است؛ صفحه را دوباره باز کنید.');
    }
    _scope = key;
    return key;
  }

  Future<dynamic> call(String method, [FormMap data = const {}]) async {
    await scope();
    // Publication is deliberately not placed in the generic automatic retry queue.
    final response = await client.callMethod(
      'asoud_erp.api.v1.forms.$method',
      data: data,
    );
    final envelope = formMap(response['message']);
    if (envelope['ok'] != true) {
      throw const ApiException.protocol();
    }
    return envelope['data'];
  }

  bool unavailable(Object error) =>
      error is ApiException &&
      (error.kind == ApiFailureKind.network ||
          error.kind == ApiFailureKind.timeout ||
          (error.kind == ApiFailureKind.server &&
              const [502, 503, 504].contains(error.statusCode)));

  Future<List<FormMap>> drafts() async {
    final key = await scope();
    final raw = (await SharedPreferences.getInstance()).getString(
      '$key:drafts',
    );
    return raw == null ? [] : formMaps(jsonDecode(raw));
  }

  Future<void> keepDraft(FormMap record) => _persist(() async {
        final rows = await drafts();
        rows.removeWhere((r) =>
            r['client_id'] == record['client_id'] ||
            (record['name'] != null && r['name'] == record['name']));
        rows.insert(0, copyForm(record));
        final saved = await (await SharedPreferences.getInstance()).setString(
          '$_scope:drafts',
          jsonEncode(rows),
        );
        if (!saved) {
          throw StateError('ذخیره روی دستگاه ناموفق بود.');
        }
      });

  Future<void> discardDraft(String id) => _persist(() async {
        final rows = await drafts();
        rows.removeWhere((r) => r['client_id'] == id);
        await (await SharedPreferences.getInstance()).setString(
          '$_scope:drafts',
          jsonEncode(rows),
        );
      });

  Future<FormMap?> entryDraft(String name) async {
    final key = await scope();
    final raw =
        (await SharedPreferences.getInstance()).getString('$key:entry:$name');
    return raw == null ? null : formMap(jsonDecode(raw));
  }

  Future<void> saveEntryDraft(String name, FormMap data) => _persist(() async {
        final key = await scope();
        if (!await (await SharedPreferences.getInstance())
            .setString('$key:entry:$name', jsonEncode(data))) {
          throw StateError('ذخیره پیش‌نویس ثبت ناموفق بود.');
        }
      });

  Future<void> discardEntryDraft(String name) => _persist(() async {
        final key = await scope();
        await (await SharedPreferences.getInstance())
            .remove('$key:entry:$name');
      });

  Future<FormMap> save(FormMap record) async {
    final prepared = {
      ...record,
      'schema': migrateFormSchema(formMap(record['schema'])),
    };
    await keepDraft(prepared);
    if (!client.isAuthenticated) {
      return {...prepared, 'local': true};
    }
    try {
      final result = formMap(
        await call('save_form', {
          'company': company,
          'schema': jsonEncode(prepared['schema']),
          'name': prepared['name'],
          'client_id': prepared['client_id'],
          'expected_version': prepared['draft_version'] ?? 0,
        }),
      );
      await discardDraft('${prepared['client_id']}');
      return {...result, 'client_id': prepared['client_id']};
    } catch (error) {
      if (!unavailable(error)) {
        rethrow;
      }
      return {...prepared, 'local': true};
    }
  }

  Future<List<FormMap>> list(String kind, {bool manage = true}) async {
    final key = await scope();
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$key:$kind:$manage';
    List<FormMap> rows;
    try {
      rows = formMaps(
        await call('list_forms', {
          'company': company,
          'kind': kind,
          'manage': manage ? 1 : 0,
        }),
      );
      if (manage) {
        await prefs.setString(cacheKey, jsonEncode(rows));
      }
    } catch (error) {
      if (!manage || (!unavailable(error) && client.isAuthenticated)) {
        rethrow;
      }
      rows = formMaps(jsonDecode(prefs.getString(cacheKey) ?? '[]'))
          .map((r) => {...r, 'cached': true})
          .toList();
    }
    if (manage) {
      final local = (await drafts())
          .where((r) => formMap(r['schema'])['kind'] == kind)
          .toList();
      rows = rows
          .where(
            (r) =>
                !local.any((l) => l['name'] != null && l['name'] == r['name']),
          )
          .toList();
      rows.insertAll(0, local.map((r) => {...r, 'local': true}));
    }
    return rows.map(migrateFormRecord).toList();
  }
}
