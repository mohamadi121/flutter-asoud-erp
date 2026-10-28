import '../../../core/network/api_exception.dart';
import '../../../core/network/frappe_client.dart';
import '../domain/entities/workflow_definition.dart';
import 'repositories/frappe_workflow_repository.dart';

class WorkflowTemplate {
  const WorkflowTemplate({required this.id, required this.title, required this.modified,
    required this.module, required this.targetDoctype, this.description = '',
    this.icon = 'hub', this.color = '#315CF5', this.steps = 0});
  factory WorkflowTemplate.fromJson(Map row) {
    for (final key in ['name', 'workflow_title', 'modified', 'module_key', 'target_doctype']) {
      if (row[key] is! String || (row[key] as String).isEmpty) throw const ApiException.protocol();
    }
    return WorkflowTemplate(id: row['name'] as String, title: row['workflow_title'] as String,
        modified: row['modified'] as String, module: row['module_key'] as String,
        targetDoctype: row['target_doctype'] as String,
        description: row['process_description'] as String? ?? '',
        icon: row['icon_key'] as String? ?? 'hub', color: row['color_hex'] as String? ?? '#315CF5',
        steps: int.tryParse('${row['steps_count']}') ?? 0);
  }
  final String id, title, modified, module, targetDoctype, description, icon, color;
  final int steps;
}

class WorkflowTemplatePage {
  const WorkflowTemplatePage(this.items, this.nextStart);
  final List<WorkflowTemplate> items;
  final int? nextStart;
}

class WorkflowTemplateRepository {
  const WorkflowTemplateRepository(this.client);
  final FrappeApiClient client;
  void _requireOnline() {
    if (!client.isAuthenticated) {
      throw const ApiException(kind: ApiFailureKind.unauthenticated,
          message: 'انتخاب الگوی واقعی گردش کار نیازمند ورود به سرور است.');
    }
  }
  Future<WorkflowTemplatePage> catalog({required String company, String search = '',
      String module = '', int start = 0}) async {
    _requireOnline();
    final value = await client.callAsoudMethod('asoud_erp.api.v1.workflow_templates.catalog',
        data: {'company': company, 'search': search, 'module_key': module, 'start': start, 'page_length': 20});
    if (value is! Map || value['items'] is! List ||
        (value['next_start'] != null && value['next_start'] is! int)) {
      throw const ApiException.protocol();
    }
    return WorkflowTemplatePage([for (final row in value['items'] as List)
      if (row is Map) WorkflowTemplate.fromJson(row) else throw const ApiException.protocol()],
      value['next_start'] as int?);
  }
  Future<WorkflowDefinition> copy({required String company, required WorkflowTemplate source,
      required String title, required String description, required String icon, required String color}) async {
    _requireOnline();
    final value = await client.callAsoudMethod('asoud_erp.api.v1.workflow_templates.create_from_template',
        data: {'company': company, 'source': source.id, 'source_modified': source.modified,
          'workflow_title': title, 'process_description': description, 'icon_key': icon, 'color_hex': color});
    if (value is! Map) throw const ApiException.protocol();
    return FrappeWorkflowRepository(client).parseDefinition(value);
  }
}
