import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/frappe_client.dart';
import '../domain/entities/document_template.dart';
import 'demo/template_demo_data.dart';
import 'offline_preview_data.dart';

/// Server calls for stage exit routes and document templates
/// (`asoud_erp.api.v1.workflow.save_stage_routes`,
/// `asoud_erp.api.v1.document_templates`).
///
/// In the offline preview (no session), templates are kept on this device so
/// the screens can be tried; nothing is queued for the server.
class WorkflowAutomationRepository {
  const WorkflowAutomationRepository(this.client);

  final FrappeApiClient client;

  /// No local-success fallback: capabilities and permissions belong to the server.
  Future<Map<String, dynamic>> automaticActionOptions(
          String definition, String stage) async =>
      _object(await _call('asoud_erp.api.v1.automatic_actions.options', {
        'definition': definition,
        'stage': stage,
      }));

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
      final stored = await _localRows();
      final rows = kind == 'ready'
          ? [
              for (final preset in offlinePresets)
                {...preset, 'name': preset['key'], 'kind': 'ready'}
            ]
          // Fresh preview: three demo templates built from the presets so
          // the flow can be tried. Once a template is saved on the device,
          // only the saved rows are listed.
          : [...stored, if (stored.isEmpty) ...demoTemplateRows()];
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
      if (name.startsWith('LOCAL-DEMO-TPL-')) {
        throw StateError('الگوی نمایشی قابل تغییر وضعیت نیست.');
      }
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
