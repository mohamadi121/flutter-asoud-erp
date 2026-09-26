import '../../../core/network/frappe_client.dart';
import '../domain/entities/document_template.dart';

/// Server calls for stage exit routes and document templates
/// (`asoud_erp.api.v1.workflow.save_stage_routes`,
/// `asoud_erp.api.v1.document_templates`).
class WorkflowAutomationRepository {
  const WorkflowAutomationRepository(this.client);

  final FrappeApiClient client;

  static const _templates = 'asoud_erp.api.v1.document_templates';

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
      DocumentTemplateOptions.fromJson(
          _object(await _call('$_templates.document_template_options', {
        'company': company,
        if (workflow != null && workflow.isNotEmpty) 'workflow': workflow,
      })));

  Future<List<LinkOption>> linkOptions(
          {required String company,
          required String targetType,
          String txt = ''}) async =>
      _list(await _call('$_templates.document_template_link_options', {
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
  }) async =>
      _list(await _call('$_templates.list_document_templates', {
        'company': company,
        'kind': kind,
        if (module != null) 'module': module,
        if (documentType != null) 'document_type': documentType,
        if (search.trim().isNotEmpty) 'search': search.trim(),
      }))
          .map(DocumentTemplate.fromJson)
          .toList();

  Future<DocumentTemplate> template(String name) async =>
      DocumentTemplate.fromJson(_object(
          await _call('$_templates.get_document_template', {'name': name})));

  Future<DocumentTemplate> saveTemplate({
    required String company,
    required DocumentTemplate template,
    String? sourceWorkflow,
  }) async =>
      DocumentTemplate.fromJson(
          _object(await _call('$_templates.save_document_template', {
        'company': company,
        'template': template.toJson(),
        if (template.name.isNotEmpty && !template.isReady)
          'name': template.name,
        if (sourceWorkflow != null && sourceWorkflow.isNotEmpty)
          'source_workflow': sourceWorkflow,
        if (template.presetKey.isNotEmpty) 'preset_key': template.presetKey,
      })));

  Future<DocumentTemplate> setTemplateStatus(
          String name, String status) async =>
      DocumentTemplate.fromJson(_object(await _call(
          '$_templates.set_document_template_status',
          {'name': name, 'status': status})));
}
