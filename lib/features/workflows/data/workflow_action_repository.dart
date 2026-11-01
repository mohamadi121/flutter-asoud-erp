import '../../../core/network/api_exception.dart';
import '../../form_builder/form_repository.dart';

/// Uses the existing runtime only, without offline-queued completion success.
class WorkflowActionRepository extends FormRepository
    implements FormAttachmentPolicy {
  WorkflowActionRepository(super.client, super.company, this.task,
      {required this.uploads, this.onUploadChanged});
  final String task;
  final bool uploads;
  final void Function(bool)? onUploadChanged;
  int _uploadsInFlight = 0;
  final Map<String, String> labels = {};
  @override
  Future<FormMap> callEnvelope(String method, [FormMap data = const {}]) =>
      super.callEnvelope(method,
          method == 'get_link_options' ? {...data, 'task': task} : data);
  @override
  bool get allowUploads => uploads;
  @override
  bool get appendUploads => true;
  @override
  String fileLabel(Object? value) {
    if (value == null || value == '') return 'فایل انتخاب نشده';
    final names = value is List ? value : [value];
    return names.map((name) => labels['$name'] ?? 'پیوست ذخیره‌شده').join('، ');
  }

  Future<FormMap> runtime(String method, FormMap data) async {
    final raw = await client.callMethod(
        'asoud_erp.api.v1.workflow_runtime.$method',
        data: {'task': task, ...data});
    final envelope = raw['message'];
    if (envelope is! Map ||
        envelope['ok'] != true ||
        envelope['data'] is! Map) {
      throw const ApiException.protocol();
    }
    return formMap(envelope['data']);
  }

  Future<void> perform(String action, FormMap values) async {
    final result = await runtime(
        'complete_workflow_task', {'action': action, 'response': values});
    if (result['task'] != task ||
        (action == 'Claim' && result['claimed'] != true) ||
        ({'Follow Up', 'Blocked'}.contains(action) &&
            result['saved'] != true)) {
      throw const ApiException.protocol();
    }
  }

  Future<void> draft(FormMap values) async {
    final result =
        await runtime('save_workflow_task_draft', {'response': values});
    if (result['task'] != task || result['saved'] != true) {
      throw const ApiException.protocol();
    }
  }

  @override
  Future<dynamic> call(String method, [FormMap data = const {}]) async {
    if (method != 'upload_file') return super.call(method, data);
    if (!uploads) {
      throw StateError('افزودن پیوست جدید برای این اقدام مجاز نیست.');
    }
    _uploadsInFlight++;
    onUploadChanged?.call(true);
    try {
      final result = await runtime('upload_workflow_attachment',
          {'filename': data['filename'], 'content_base64': data['content']});
      if (result['name'] is! String) throw const ApiException.protocol();
      labels['${result['name']}'] = '${result['file_name'] ?? 'پیوست'}';
      return {'name': result['name'], 'label': result['file_name']};
    } finally {
      _uploadsInFlight--;
      onUploadChanged?.call(_uploadsInFlight > 0);
    }
  }
}
