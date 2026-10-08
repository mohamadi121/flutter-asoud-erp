import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/frappe_client.dart';
import '../../../core/offline/local_database_store.dart';
import '../../../core/offline/local_record.dart';
import '../../../core/offline/offline_failure.dart';
import '../domain/entities/document_template.dart';
import 'offline_preview_data.dart';

class AutomaticActionOptions {
  const AutomaticActionOptions({
    required this.data,
    required this.fromCache,
    this.connectionError,
    this.pendingDraft,
  });

  final Map<String, dynamic> data;
  final bool fromCache;
  final String? connectionError;
  final Map<String, dynamic>? pendingDraft;
}

/// Server calls for stage exit routes and document templates
/// (`asoud_erp.api.v1.workflow.save_stage_routes`,
/// `asoud_erp.api.v1.document_templates`).
///
/// In the offline preview (no session), templates are kept on this device so
/// the screens can be tried; nothing is queued for the server.
class WorkflowAutomationRepository {
  const WorkflowAutomationRepository(this.client, {LocalRecordStore? local})
      : _local = local;

  final FrappeApiClient client;
  final LocalRecordStore? _local;

  static const _automaticActionOptionsPrefix =
      'asoud_automatic_action_options_v2_';
  static const _automaticActionSave = 'asoud_erp.api.v1.automatic_actions.save';

  Future<String> _draftKey(String definition, String stage) async {
    final owner = isLocal
        ? '__offline_preview__'
        : (await client.getCurrentUser()).userId;
    return '${_automaticActionCacheKey(definition: definition, stage: stage, userId: owner)}_draft';
  }

  Future<Map<String, dynamic>?> automaticActionDraft(
      String definition, String stage) async {
    final key = await _draftKey(definition, stage);
    final raw = (await SharedPreferences.getInstance()).getString(key);
    return raw == null ? null : _object(jsonDecode(raw));
  }

  Future<void> saveAutomaticActionDraft(
      String definition, String stage, Map<String, dynamic> draft) async {
    final key = await _draftKey(definition, stage);
    final saved = await (await SharedPreferences.getInstance())
        .setString(key, jsonEncode(draft));
    if (!saved) throw StateError('ذخیرهٔ پیش‌نویس روی دستگاه ناموفق بود.');
  }

  Future<void> clearAutomaticActionDraft(
      String definition, String stage) async {
    final key = await _draftKey(definition, stage);
    await (await SharedPreferences.getInstance()).remove(key);
  }

  /// Uses only previously authorized options for this user, server and stage
  /// during a network outage; the server still validates every save.
  Future<AutomaticActionOptions> automaticActionOptions(
      String definition, String stage) async {
    final user = await client.getCurrentUser();
    final key = _automaticActionCacheKey(
        definition: definition, stage: stage, userId: user.userId);
    try {
      final result = _object(await _call(
          'asoud_erp.api.v1.automatic_actions.options',
          {'definition': definition, 'stage': stage}));
      if (result['schema_version'] != 2) {
        throw StateError('نسخه سرور از این فرم پشتیبانی نمی‌کند.');
      }
      final prefs = await SharedPreferences.getInstance();
      final stored = await prefs.setString(key, jsonEncode(result));
      if (!stored) {
        throw StateError('ذخیرهٔ اطلاعات فرم روی دستگاه ناموفق بود.');
      }
      return AutomaticActionOptions(
        data: result,
        fromCache: false,
        pendingDraft: await _pendingAutomaticActionDraft(
          definition: definition,
          stage: stage,
          userId: user.userId,
        ),
      );
    } on ApiException catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) rethrow;
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['schema_version'] != 2) {
        throw StateError('اطلاعات ذخیره‌شدهٔ فرم اقدام خودکار معتبر نیست.');
      }
      return AutomaticActionOptions(
        data: Map<String, dynamic>.from(decoded),
        fromCache: true,
        connectionError: error.message,
        pendingDraft: await _pendingAutomaticActionDraft(
          definition: definition,
          stage: stage,
          userId: user.userId,
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> _pendingAutomaticActionDraft({
    required String definition,
    required String stage,
    required String userId,
  }) async {
    final server = _serverIdentity;
    final records = await (_local ?? LocalDatabaseStore.instance).list(
      entityType: _automaticActionSave,
      statuses: const {
        LocalSyncStatus.localOnly,
        LocalSyncStatus.pendingSync,
      },
    );
    for (final record in records) {
      final payload = record.payload;
      if (payload['operation'] != 'asoud_method' ||
          payload['_asoud_owner'] != userId ||
          payload['_asoud_server'] != server ||
          payload['definition'] != definition ||
          payload['stage'] != stage) {
        continue;
      }
      return {
        'config': payload['config'],
        'routes': payload['routes'],
      };
    }
    return null;
  }

  String get _serverIdentity {
    final identity =
        client is FrappeClient ? (client as FrappeClient).serverIdentity : null;
    return identity is String && identity.isNotEmpty
        ? identity
        : AppConfig.erpNextBaseUrl;
  }

  String _automaticActionCacheKey({
    required String definition,
    required String stage,
    required String userId,
  }) =>
      '$_automaticActionOptionsPrefix${base64Url.encode(utf8.encode(jsonEncode([
            _serverIdentity,
            userId,
            definition,
            stage,
          ])))}';

  Future<void> saveAutomaticAction(
      {required String definition,
      required String stage,
      required Map<String, dynamic> config,
      required Map<String, String> routes}) async {
    await _call('asoud_erp.api.v1.automatic_actions.save', {
      'definition': definition,
      'stage': stage,
      'config': config,
      'routes': routes,
    });
  }

  static const _templates = 'asoud_erp.api.v1.document_templates';
  static const _localKey = 'asoud_document_templates_local_v1';

  Future<List<Map<String, dynamic>>> userTaskRequests(String company) async {
    final key = '${await _draftKey(company, 'request-types')}_options';
    final prefs = await SharedPreferences.getInstance();
    try {
      final rows = _list(await _call(
          'asoud_erp.api.v1.workflow_request.request_options',
          {'company': company}));
      await prefs.setString(key, jsonEncode(rows));
      return rows;
    } catch (error) {
      if (!isRetryableOfflineFailure(error)) rethrow;
      final cached = prefs.getString(key);
      if (cached == null) rethrow;
      return _list(jsonDecode(cached));
    }
  }

  /// True in the offline preview: templates are read and saved locally.
  bool get isLocal => AppConfig.offlineDemoMode && !client.isAuthenticated;

  Future<List<Map<String, dynamic>>> _localRows() async {
    final raw = (await SharedPreferences.getInstance()).getString(_localKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _storeRows(List<Map<String, dynamic>> rows) async =>
      (await SharedPreferences.getInstance())
          .setString(_localKey, jsonEncode(rows));

  bool _matches(DocumentTemplate row, String? module, String? documentType,
          String search) =>
      (module == null || row.module == module) &&
      (documentType == null || row.documentType == documentType) &&
      (search.trim().isEmpty || row.title.contains(search.trim()));

  Future<dynamic> _call(String method, Map<String, dynamic> data) =>
      client.callAsoudMethod(method, data: data);

  Map<String, dynamic> _object(Object? value) {
    if (value is! Map) throw StateError('پاسخ سرور معتبر نیست.');
    return Map<String, dynamic>.from(value);
  }

  List<Map<String, dynamic>> _list(Object? value) {
    if (value is! List) throw StateError('پاسخ سرور معتبر نیست.');
    return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  /// Sets a stage's exits by decision; an empty target removes the route.
  Future<void> saveStageRoutes({
    required String definition,
    required String stage,
    required Map<String, String> routes,
  }) =>
      _call('asoud_erp.api.v1.workflow.save_stage_routes', {
        'definition': definition,
        'stage': stage,
        'routes': routes,
      });

  Future<DocumentTemplateOptions> templateOptions(
          {required String company, String? workflow}) async =>
      isLocal
          ? DocumentTemplateOptions.fromJson(
              await offlineTemplateOptions(workflow))
          : DocumentTemplateOptions.fromJson(
              _object(await _call('$_templates.document_template_options', {
              'company': company,
              if (workflow != null && workflow.isNotEmpty) 'workflow': workflow,
            })));

  Future<List<LinkOption>> linkOptions(
          {required String company,
          required String targetType,
          String txt = ''}) async =>
      isLocal
          ? [
              for (final row in offlineLinkOptions[targetType] ?? const [])
                if (txt.isEmpty || row['label']!.contains(txt))
                  LinkOption.fromJson(row)
            ]
          : _list(await _call('$_templates.document_template_link_options', {
              'company': company,
              'target_type': targetType,
              'txt': txt,
            }))
              .map(LinkOption.fromJson)
              .toList();

  Future<List<DocumentTemplate>> templates({
    required String company,
    String kind = 'custom',
    String? module,
    String? documentType,
    String search = '',
  }) async {
    if (isLocal) {
      final rows = kind == 'ready'
          ? [
              for (final preset in offlinePresets)
                {...preset, 'name': preset['key'], 'kind': 'ready'}
            ]
          : await _localRows();
      return rows
          .map(DocumentTemplate.fromJson)
          .where((row) => _matches(row, module, documentType, search))
          .toList();
    }
    return _list(await _call('$_templates.list_document_templates', {
      'company': company,
      'kind': kind,
      if (module != null) 'module': module,
      if (documentType != null) 'document_type': documentType,
      if (search.trim().isNotEmpty) 'search': search.trim(),
    }))
        .map(DocumentTemplate.fromJson)
        .toList();
  }

  Future<DocumentTemplate> template(String name) async {
    if (isLocal) {
      final row =
          (await _localRows()).where((row) => row['name'] == name).firstOrNull;
      if (row == null) throw StateError('این الگو روی گوشی یافت نشد.');
      return DocumentTemplate.fromJson(row);
    }
    return DocumentTemplate.fromJson(_object(
        await _call('$_templates.get_document_template', {'name': name})));
  }

  Future<DocumentTemplate> saveTemplate({
    required String company,
    required DocumentTemplate template,
    String? sourceWorkflow,
  }) async {
    if (isLocal) return _saveLocal(company, template, sourceWorkflow);
    return DocumentTemplate.fromJson(
        _object(await _call('$_templates.save_document_template', {
      'company': company,
      'template': template.toJson(),
      if (template.name.isNotEmpty && !template.isReady) 'name': template.name,
      if (sourceWorkflow != null && sourceWorkflow.isNotEmpty)
        'source_workflow': sourceWorkflow,
      if (template.presetKey.isNotEmpty) 'preset_key': template.presetKey,
    })));
  }

  Future<DocumentTemplate> _saveLocal(
      String company, DocumentTemplate template, String? sourceWorkflow) async {
    if (template.title.trim().length < 2) {
      throw StateError('نام الگو را وارد کنید.');
    }
    final rows = await _localRows();
    final existing = template.isReady
        ? -1
        : rows.indexWhere(
            (row) => template.name.isNotEmpty && row['name'] == template.name);
    final name = existing >= 0
        ? template.name
        : 'LOCAL-TPL-${DateTime.now().microsecondsSinceEpoch}';
    final row = {
      ...template.toJson(),
      'name': name,
      'company': company,
      'status': existing >= 0 ? rows[existing]['status'] : 'Active',
      'kind': 'custom',
      'preset_key': template.presetKey,
      'source_workflow': sourceWorkflow ?? '',
      'icon': template.icon,
      'local': true,
    };
    if (existing >= 0) {
      rows[existing] = row;
    } else {
      rows.insert(0, row);
    }
    await _storeRows(rows);
    return DocumentTemplate.fromJson(row);
  }

  Future<DocumentTemplate> setTemplateStatus(String name, String status) async {
    if (isLocal) {
      final rows = await _localRows();
      final index = rows.indexWhere((row) => row['name'] == name);
      if (index < 0) throw StateError('این الگو روی گوشی یافت نشد.');
      rows[index] = {...rows[index], 'status': status};
      await _storeRows(rows);
      return DocumentTemplate.fromJson(rows[index]);
    }
    return DocumentTemplate.fromJson(_object(await _call(
        '$_templates.set_document_template_status',
        {'name': name, 'status': status})));
  }
}
