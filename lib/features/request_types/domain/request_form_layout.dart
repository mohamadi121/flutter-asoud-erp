import '../../workflows/domain/entities/workflow_definition.dart';

/// Presentation only: base fields keep their native request identity.
const requestBaseLayout = {
  'base:number': 'شماره درخواست',
  'base:author': 'ثبت‌کننده درخواست',
  'base:department': 'واحد سازمانی',
  'base:date': 'تاریخ ثبت',
  'base:status': 'وضعیت درخواست',
  'base:description': 'شرح درخواست',
  'base:attachments': 'فایل پیوست',
};

class RequestFieldPlacement {
  const RequestFieldPlacement(this.key, {this.fullWidth = false});
  final String key;
  final bool fullWidth;
  Map<String, dynamic> toMap() => {'key': key, 'span': fullWidth ? 2 : 1};
}

List<RequestFieldPlacement> normalizeRequestLayout(
    List<WorkflowFormFieldDefinition> fields, Iterable<dynamic> saved) {
  final allowed = {
    ...requestBaseLayout.keys,
    ...fields.map((field) => field.key)
  };
  final seen = <String>{};
  final result = <RequestFieldPlacement>[];
  for (final raw in saved) {
    if (raw is! Map) continue;
    final key = raw['key']?.toString() ?? '';
    if (allowed.contains(key) && seen.add(key)) {
      result.add(RequestFieldPlacement(key, fullWidth: raw['span'] == 2));
    }
  }
  for (final key in allowed) {
    if (!seen.add(key)) continue;
    final field = fields.where((field) => field.key == key).firstOrNull;
    result.add(RequestFieldPlacement(key,
        fullWidth: key == 'base:description' ||
            key == 'base:attachments' ||
            field?.type == 'Table' ||
            field?.type == 'Item Table' ||
            field?.type == 'Long Text'));
  }
  return result;
}
