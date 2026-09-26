/// Document templates («الگوهای سند») used by the workflow "Create Document"
/// automatic action. Mirrors `asoud_erp.api.v1.document_templates`.
library;

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};
List<Map<String, dynamic>> _rows(Object? value) => value is List
    ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
    : const [];
String _text(Object? value) => value?.toString() ?? '';

/// Where a target field takes its value from.
const valueSourceLabels = {
  'fixed': 'مقدار ثابت',
  'request': 'فیلد درخواست',
  'user': 'اطلاعات کاربر',
  'organization': 'اطلاعات سازمان',
  'system': 'مقدار سیستم',
};

const valueSourceHints = {
  'fixed': 'یک مقدار مشخص وارد کنید',
  'request': 'از فیلدهای فرم درخواست',
  'user': 'اطلاعات کاربر درخواست‌کننده (نام، واحد و ...)',
  'organization': 'اطلاعات شرکت جاری (نام، ارز و ...)',
  'system': 'تاریخ روز، شماره سریال و ...',
};

class DocumentTypeOption {
  const DocumentTypeOption(
      {required this.key, required this.label, this.enabled = true});
  factory DocumentTypeOption.fromJson(Map<String, dynamic> json) =>
      DocumentTypeOption(
          key: _text(json['key']),
          label: _text(json['label']),
          enabled: json['enabled'] != false);
  final String key, label;
  final bool enabled;
}

class DocumentModule {
  const DocumentModule(
      {required this.key,
      required this.label,
      this.description = '',
      this.types = const []});
  factory DocumentModule.fromJson(Map<String, dynamic> json) => DocumentModule(
      key: _text(json['key']),
      label: _text(json['label']),
      description: _text(json['description']),
      types: _rows(json['types']).map(DocumentTypeOption.fromJson).toList());
  final String key, label, description;
  final List<DocumentTypeOption> types;
  bool get available => types.any((type) => type.enabled);
}

class DocumentTargetField {
  const DocumentTargetField(
      {required this.key,
      required this.label,
      required this.type,
      this.required = false});
  factory DocumentTargetField.fromJson(Map<String, dynamic> json) =>
      DocumentTargetField(
          key: _text(json['key']),
          label: _text(json['label']),
          type: _text(json['type']),
          required: json['required'] == true);
  final String key, label, type;
  final bool required;

  /// ERPNext records chosen from a list (accounts, cost centers, ...).
  bool get isLink =>
      const {'Account', 'Cost Center', 'Project', 'Warehouse'}.contains(type);
}

class DocumentValueOption {
  const DocumentValueOption(
      {required this.key, required this.label, this.type = ''});
  factory DocumentValueOption.fromJson(Map<String, dynamic> json) =>
      DocumentValueOption(
          key: _text(json['key']),
          label: _text(json['label']),
          type: _text(json['type']));
  final String key, label, type;
}

class DocumentTemplateOptions {
  const DocumentTemplateOptions(
      {this.modules = const [],
      this.fields = const {},
      this.sources = const {},
      this.placeholders = const []});
  factory DocumentTemplateOptions.fromJson(Map<String, dynamic> json) =>
      DocumentTemplateOptions(
        modules: _rows(json['modules']).map(DocumentModule.fromJson).toList(),
        fields: {
          for (final entry in _map(json['fields']).entries)
            entry.key:
                _rows(entry.value).map(DocumentTargetField.fromJson).toList(),
        },
        sources: {
          for (final entry in _map(json['sources']).entries)
            entry.key:
                _rows(entry.value).map(DocumentValueOption.fromJson).toList(),
        },
        placeholders: [
          for (final item in (json['placeholders'] as List? ?? const []))
            item.toString()
        ],
      );
  final List<DocumentModule> modules;
  final Map<String, List<DocumentTargetField>> fields;
  final Map<String, List<DocumentValueOption>> sources;
  final List<String> placeholders;

  DocumentModule? module(String key) {
    for (final module in modules) {
      if (module.key == key) return module;
    }
    return null;
  }

  String typeLabel(String key) {
    for (final module in modules) {
      for (final type in module.types) {
        if (type.key == key) return type.label;
      }
    }
    return key;
  }
}

class ValueSource {
  const ValueSource({required this.source, required this.value});
  factory ValueSource.fromJson(Map<String, dynamic> json) =>
      ValueSource(source: _text(json['source']), value: _text(json['value']));
  final String source, value;
  Map<String, dynamic> toJson() => {'source': source, 'value': value};
}

class DocumentTemplate {
  const DocumentTemplate({
    this.name = '',
    required this.title,
    required this.module,
    required this.documentType,
    this.description = '',
    this.mapping = const {},
    this.createAsDraft = true,
    this.autoSubmit = false,
    this.reusable = true,
    this.managerNote = '',
    this.status = 'Active',
    this.kind = 'custom',
    this.presetKey = '',
    this.sourceWorkflow = '',
    this.icon = '',
  });

  factory DocumentTemplate.fromJson(Map<String, dynamic> json) =>
      DocumentTemplate(
        name: _text(json['name']),
        title: _text(json['title']),
        module: _text(json['module']),
        documentType: _text(json['document_type']),
        description: _text(json['description']),
        mapping: {
          for (final entry in _map(json['mapping']).entries)
            entry.key: ValueSource.fromJson(_map(entry.value)),
        },
        createAsDraft: json['create_as_draft'] != false,
        autoSubmit: json['auto_submit'] == true,
        reusable: json['reusable'] != false,
        managerNote: _text(json['manager_note']),
        status: json['status'] == null ? 'Active' : _text(json['status']),
        kind: json['kind'] == null ? 'custom' : _text(json['kind']),
        presetKey: _text(json['preset_key'] ?? json['key']),
        sourceWorkflow: _text(json['source_workflow']),
        icon: _text(json['icon']),
      );

  final String name, title, module, documentType, description, managerNote;
  final String status, kind, presetKey, sourceWorkflow, icon;
  final Map<String, ValueSource> mapping;
  final bool createAsDraft, autoSubmit, reusable;

  bool get isReady => kind == 'ready';
  bool get isActive => status == 'Active';

  DocumentTemplate copyWith({
    String? title,
    String? module,
    String? documentType,
    String? description,
    Map<String, ValueSource>? mapping,
    bool? createAsDraft,
    bool? autoSubmit,
    bool? reusable,
    String? managerNote,
  }) =>
      DocumentTemplate(
        name: name,
        title: title ?? this.title,
        module: module ?? this.module,
        documentType: documentType ?? this.documentType,
        description: description ?? this.description,
        mapping: mapping ?? this.mapping,
        createAsDraft: createAsDraft ?? this.createAsDraft,
        autoSubmit: autoSubmit ?? this.autoSubmit,
        reusable: reusable ?? this.reusable,
        managerNote: managerNote ?? this.managerNote,
        status: status,
        kind: kind,
        presetKey: presetKey,
        sourceWorkflow: sourceWorkflow,
        icon: icon,
      );

  /// The `template` payload of `save_document_template`.
  Map<String, dynamic> toJson() => {
        'title': title,
        'module': module,
        'document_type': documentType,
        'description': description,
        'mapping': {
          for (final entry in mapping.entries) entry.key: entry.value.toJson()
        },
        'create_as_draft': autoSubmit ? false : createAsDraft,
        'auto_submit': autoSubmit,
        'reusable': reusable,
        'manager_note': managerNote,
      };
}

class LinkOption {
  const LinkOption({required this.value, required this.label});
  factory LinkOption.fromJson(Map<String, dynamic> json) =>
      LinkOption(value: _text(json['value']), label: _text(json['label']));
  final String value, label;
}
