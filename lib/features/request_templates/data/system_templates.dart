import 'system_template_fields.dart';

export 'system_template_fields.dart';

/// The three built-in request templates (CONTRACT §3.4-3.6).
abstract final class SystemTemplateKeys {
  static const purchase = 'purchase';
  static const supply = 'supply';
  static const leave = 'leave';
  static const all = [purchase, supply, leave];
}

/// Field definitions of a system template (shared contract fixture).
List<Map<String, Object?>> systemTemplateFields(String templateKey) =>
    switch (templateKey) {
      SystemTemplateKeys.purchase => purchaseTemplateFields,
      SystemTemplateKeys.supply => supplyTemplateFields,
      SystemTemplateKeys.leave => leaveTemplateFields,
      _ => throw ArgumentError.value(templateKey, 'templateKey'),
    };

const _attachmentExtensions = [
  'pdf',
  'jpg',
  'jpeg',
  'png',
  'xls',
  'xlsx',
  'doc',
  'docx'
];

/// A `request_options` row (CONTRACT §4.1) for a system template, as the
/// preview/demo mode and the tests see it. Default values and the
/// `required_by_setting` resolution are done here like the server does.
Map<String, dynamic> systemRequestType(
  String templateKey, {
  String company = 'ASOUD Demo',
  bool costCenterRequired = true,
  double dailyWorkingHours = 8,
  String departmentValue = 'ICU - DEMO',
  String departmentLabel = 'بخش ICU',
  String branchValue = 'Tehran',
  String branchLabel = 'تهران',
  String userValue = 'ali@asoud.test',
  String userLabel = 'علی محمدی',
  String today = '',
}) {
  final fields = [
    for (final raw in systemTemplateFields(templateKey))
      _resolveField(raw,
          costCenterRequired: costCenterRequired,
          departmentValue: departmentValue,
          departmentLabel: departmentLabel,
          branchValue: branchValue,
          branchLabel: branchLabel,
          userValue: userValue,
          userLabel: userLabel,
          today: today),
  ];
  final meta = switch (templateKey) {
    SystemTemplateKeys.purchase => (
        title: 'درخواست خرید کالا',
        short: 'ثبت درخواست خرید کالا',
        description:
            'درخواست خرید کالا توسط کارکنان؛ پس از تأیید مدیر مستقیم، درخواست مواد (خرید) ایجاد می‌شود.',
        prefix: 'PR',
        category: 'Purchase',
        module: 'Purchase',
        icon: 'purchase',
        color: '#1769F6',
        subjectMode: 'input',
        subjectLabel: 'عنوان درخواست',
        extensions: _attachmentExtensions,
      ),
    SystemTemplateKeys.supply => (
        title: 'درخواست تأمین کالا / خدمت',
        short: 'ثبت درخواست تأمین کالا / خدمت',
        description:
            'درخواست تأمین کالا یا خدمت؛ بر اساس روش تأمین، پس از تأیید مدیر مستقیم درخواست مواد ایجاد می‌شود.',
        prefix: 'SP',
        category: 'Purchase',
        module: 'Inventory',
        icon: 'purchase',
        color: '#0E9F6E',
        subjectMode: 'input',
        subjectLabel: 'عنوان درخواست',
        extensions: _attachmentExtensions,
      ),
    _ => (
        title: 'درخواست مرخصی',
        short: 'ثبت درخواست مرخصی',
        description:
            'درخواست مرخصی روزانه یا ساعتی؛ پس از تأیید مدیر مستقیم مرخصی در سیستم منابع انسانی ثبت می‌شود.',
        prefix: 'LV',
        category: 'HR',
        module: 'HR',
        icon: 'leave',
        color: '#0E9F6E',
        subjectMode: 'generated',
        subjectLabel: '',
        extensions: const ['jpg', 'jpeg', 'png', 'pdf', 'docx'],
      ),
  };
  final code = 'SYS-${templateKey.toUpperCase()}-WP';
  return {
    'name': code,
    'workflow_code': code,
    'workflow_title': meta.title,
    'short_title': meta.short,
    'process_description': meta.description,
    'company': company,
    'module_key': meta.module,
    'request_category': meta.category,
    'icon_key': meta.icon,
    'color_hex': meta.color,
    'show_in_request_list': 1,
    'template_key': templateKey,
    'template_version': 1,
    'subject_mode': meta.subjectMode,
    'subject_label': meta.subjectLabel,
    'number_prefix': meta.prefix,
    'settings': {
      'cost_center_required': costCenterRequired,
      'daily_working_hours': dailyWorkingHours,
    },
    'attachments': {
      'max_files': 10,
      'max_mb': 10,
      'extensions': meta.extensions,
    },
    'fields': fields,
  };
}

Map<String, dynamic> _resolveField(
  Map<String, Object?> raw, {
  required bool costCenterRequired,
  required String departmentValue,
  required String departmentLabel,
  required String branchValue,
  required String branchLabel,
  required String userValue,
  required String userLabel,
  required String today,
}) {
  final field = Map<String, dynamic>.from(raw);
  final source = field.remove('default_source');
  switch (source) {
    case 'session_user':
      field['default_value'] = userValue;
      field['default_label'] = userLabel;
    case 'employee_department':
      field['default_value'] = departmentValue;
      field['default_label'] = departmentLabel;
    case 'employee_branch':
      field['default_value'] = branchValue;
      field['default_label'] = branchLabel;
    case 'today':
      field['default_value'] = today;
  }
  if (field.remove('required_by_setting') != null) {
    field['required'] = costCenterRequired;
  }
  return field;
}
