enum AutomaticActionType {
  createRequest('Create Request', 'ایجاد درخواست جدید'),
  createDocument('Create Document', 'ایجاد سند جدید'),
  updateFields('Update Fields', 'به‌روزرسانی چند فیلد'),
  changeStatus('Change Status', 'تغییر وضعیت'),
  notify('Send Notification', 'ارسال اعلان'),
  calculate('Calculate Value', 'محاسبه و ثبت مقدار'),
  link('Link Record', 'اتصال به رکورد دیگر');

  const AutomaticActionType(this.key, this.label);
  final String key;
  final String label;

  static AutomaticActionType parse(String value) =>
      values.firstWhere((item) => item.key == value);
}

enum ActionSource { current, stage, constant, system }

class ActionMapping {
  const ActionMapping(
      {required this.source,
      required this.value,
      this.stage,
      this.transform = 'none',
      this.empty = 'error'});
  final ActionSource source;
  final Object value;
  final String? stage;
  final String transform;
  final String empty;

  factory ActionMapping.fromJson(Map<String, dynamic> json) => ActionMapping(
        source: ActionSource.values.byName(json['source'] as String),
        value: json['value'] as Object,
        stage: json['stage'] as String?,
        transform: json['transform'] as String? ?? 'none',
        empty: json['empty'] as String? ?? 'error',
      );

  Map<String, dynamic> toJson() => {
        'source': source.name,
        'value': value,
        if (source == ActionSource.stage) 'stage': stage,
        'transform': transform,
        'empty': empty,
      };
}

class ActionExecutionPolicy {
  const ActionExecutionPolicy(
      {this.extraAttempts = 0,
      this.retrySeconds = 60,
      this.timeoutSeconds = 120});
  final int extraAttempts;
  final int retrySeconds;
  final int timeoutSeconds;

  bool get valid =>
      extraAttempts >= 0 &&
      extraAttempts <= 5 &&
      retrySeconds >= 30 &&
      retrySeconds <= 3600 &&
      timeoutSeconds >= 10 &&
      timeoutSeconds <= 300;
  Map<String, dynamic> toJson() => {
        'extra_attempts': extraAttempts,
        'retry_seconds': retrySeconds,
        'timeout_seconds': timeoutSeconds,
      };
}

class ActionTarget {
  const ActionTarget.current() : stage = null;
  const ActionTarget.stage(this.stage);
  final String? stage;
  Map<String, dynamic> toJson() => stage == null
      ? {'source': 'current'}
      : {'source': 'stage', 'stage': stage};
}

sealed class AutomaticOperation {
  const AutomaticOperation();
  AutomaticActionType get type;
  Map<String, dynamic> toJson();
}

Map<String, dynamic> _mappingJson(Map<String, ActionMapping> mapping) =>
    mapping.map((key, value) => MapEntry(key, value.toJson()));

class CreateRequestOperation extends AutomaticOperation {
  const CreateRequestOperation(this.requestType, this.mapping,
      {this.linkOriginal = true});
  final String requestType;
  final Map<String, ActionMapping> mapping;
  final bool linkOriginal;
  @override
  AutomaticActionType get type => AutomaticActionType.createRequest;
  @override
  Map<String, dynamic> toJson() => {
        'request_type': requestType,
        'mapping': _mappingJson(mapping),
        'link_original': linkOriginal
      };
}

class CreateDocumentOperation extends AutomaticOperation {
  const CreateDocumentOperation(this.doctype, this.mapping,
      {this.initialState = 'Draft', this.linkOriginal = true});
  final String doctype;
  final Map<String, ActionMapping> mapping;
  final String initialState;
  final bool linkOriginal;
  @override
  AutomaticActionType get type => AutomaticActionType.createDocument;
  @override
  Map<String, dynamic> toJson() => {
        'doctype': doctype,
        'mapping': _mappingJson(mapping),
        'initial_state': initialState,
        'link_original': linkOriginal
      };
}

class UpdateFieldsOperation extends AutomaticOperation {
  const UpdateFieldsOperation(this.target, this.mapping);
  final ActionTarget target;
  final Map<String, ActionMapping> mapping;
  @override
  AutomaticActionType get type => AutomaticActionType.updateFields;
  @override
  Map<String, dynamic> toJson() =>
      {'target': target.toJson(), 'mapping': _mappingJson(mapping)};
}

class ChangeStatusOperation extends AutomaticOperation {
  const ChangeStatusOperation(this.target, this.transition);
  final ActionTarget target;
  final String transition;
  @override
  AutomaticActionType get type => AutomaticActionType.changeStatus;
  @override
  Map<String, dynamic> toJson() =>
      {'target': target.toJson(), 'transition': transition};
}

class NotifyOperation extends AutomaticOperation {
  const NotifyOperation(this.recipients, this.channels, this.message);
  final Set<String> recipients;
  final Set<String> channels;
  final String message;
  @override
  AutomaticActionType get type => AutomaticActionType.notify;
  @override
  Map<String, dynamic> toJson() => {
        'recipients': recipients.toList(),
        'channels': channels.toList(),
        'message': message
      };
}

class CalculateOperation extends AutomaticOperation {
  const CalculateOperation(this.target, this.field, this.method, this.inputs,
      {this.formula = ''});
  final ActionTarget target;
  final String field;
  final String method;
  final Map<String, ActionMapping> inputs;
  final String formula;
  @override
  AutomaticActionType get type => AutomaticActionType.calculate;
  @override
  Map<String, dynamic> toJson() => {
        'target': target.toJson(),
        'field': field,
        'method': method,
        'inputs': _mappingJson(inputs),
        if (method == 'formula') 'formula': formula
      };
}

class LinkRecordOperation extends AutomaticOperation {
  const LinkRecordOperation(
      this.target, this.doctype, this.lookupField, this.lookup,
      {this.relationship = 'related', this.missing = 'error'});
  final ActionTarget target;
  final String doctype;
  final String lookupField;
  final ActionMapping lookup;
  final String relationship;
  final String missing;
  @override
  AutomaticActionType get type => AutomaticActionType.link;
  @override
  Map<String, dynamic> toJson() => {
        'target': target.toJson(),
        'doctype': doctype,
        'lookup_field': lookupField,
        'lookup': lookup.toJson(),
        'relationship': relationship,
        'missing': missing,
        'multiple': 'error'
      };
}
