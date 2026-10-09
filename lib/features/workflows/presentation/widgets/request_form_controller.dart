import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../../../core/utils/jalali_date.dart';
import '../../data/generic_request_repository.dart';
import '../../domain/entities/request_models.dart';
import '../../domain/entities/workflow_definition.dart';

/// Loads choices (`{value, label, ...}`) for a field type, like
/// [GenericRequestRepository.fieldOptions].
typedef RequestFieldOptionsLoader = Future<List<Map<String, dynamic>>>
    Function(String fieldType, {String txt, String? itemCode, String? scope});

/// A file chosen by the user.
typedef RequestPickedFile = ({String filename, Uint8List bytes});

/// Lets the user choose files within [limits]; the default is
/// `pickRequestFiles` (the system file picker).
typedef RequestFilePicker = Future<List<RequestPickedFile>> Function(
    RequestAttachmentLimits limits);

const requestRequiredMessage = 'این فیلد الزامی است.';

/// Extensions the request forms accept unless the request type says otherwise.
const defaultAttachmentExtensions = [
  'pdf',
  'jpg',
  'jpeg',
  'png',
  'xls',
  'xlsx',
  'doc',
  'docx',
];

/// File limits of a request type (`attachments` of `request_options`).
class RequestAttachmentLimits {
  const RequestAttachmentLimits({
    this.maxFiles = 10,
    this.maxMb = 10,
    this.maxTotalMb = 25,
    this.extensions = defaultAttachmentExtensions,
  });

  factory RequestAttachmentLimits.fromMap(Object? source) {
    if (source is! Map) return const RequestAttachmentLimits();
    final extensions = source['extensions'];
    return RequestAttachmentLimits(
      maxFiles: (source['max_files'] as num?)?.toInt() ?? 10,
      maxMb: (source['max_mb'] as num?)?.toInt() ?? 10,
      extensions: extensions is List && extensions.isNotEmpty
          ? [for (final item in extensions) '$item'.toLowerCase()]
          : defaultAttachmentExtensions,
    );
  }

  final int maxFiles, maxMb, maxTotalMb;
  final List<String> extensions;

  int get maxBytes => maxMb * 1024 * 1024;
  int get maxTotalBytes => maxTotalMb * 1024 * 1024;

  /// «PDF، JPG، PNG» for the hint under the drop zone.
  String get extensionsLabel =>
      extensions.map((item) => item.toUpperCase()).join('، ');

  /// A file picker filter: extensions without the dot.
  List<String> get pickerExtensions => extensions;

  String limitsMessage() =>
      'حداکثر ${toPersianDigits(maxFiles)} فایل، هر فایل تا ${toPersianDigits(maxMb)} و مجموع تا ${toPersianDigits(maxTotalMb)} مگابایت؛ فرمت‌های مجاز: $extensionsLabel';
}

/// Thrown by [RequestFormController.addAttachment] for a file that breaks the
/// type's limits; [message] is Persian.
class RequestAttachmentException implements Exception {
  const RequestAttachmentException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A file chosen in the form and not uploaded yet.
class RequestAttachmentDraft {
  const RequestAttachmentDraft({
    required this.ref,
    required this.filename,
    required this.bytes,
    required this.general,
  });

  /// Unique within the controller (`att-1`, `att-2`, ...); values reference the
  /// file as `attachment:<ref>`.
  final String ref, filename;
  final Uint8List bytes;

  /// A general file is always uploaded; a field or row file only while a value
  /// references it.
  final bool general;

  int get size => bytes.length;
  String get reference => 'attachment:$ref';
  bool get isImage =>
      RegExp(r'\.(png|jpe?g)$', caseSensitive: false).hasMatch(filename);
}

/// Values, visibility, validation and files of one request form. The widgets
/// of [RequestFieldWidget] read and write it; the page submits
/// [payloadValues] and [attachmentUploads].
class RequestFormController extends ChangeNotifier {
  RequestFormController({
    required List<WorkflowFormFieldDefinition> fields,
    Map<String, dynamic> initialValues = const {},
    bool applyDefaults = true,
    this.limits = const RequestAttachmentLimits(),
    this.loadOptions,
    this.filePicker,
    this.idPrefix = '',
    this.showRequiredMarks = false,
    this.settings = const {},
    this.subjectMode = 'input',
    this.subjectLabel = 'عنوان درخواست',
    List<RequestAttachment> existingAttachments = const [],
    TextEditingController? subject,
  })  : fields = List.unmodifiable(fields),
        existingAttachments = List.unmodifiable(existingAttachments),
        subject = subject ?? TextEditingController(),
        _ownsSubject = subject == null {
    _initial = {
      for (final entry in initialValues.entries) entry.key: _copy(entry.value)
    };
    _values.addAll(_initial);
    if (applyDefaults) {
      for (final field in this.fields) {
        if (_values.containsKey(field.key)) continue;
        final initial = field.defaultValue;
        if (initial.isEmpty || field.type == 'Auto') continue;
        _values[field.key] = switch (field.type) {
          'Multi Choice' => [initial],
          'Checkbox' => initial == 'true' || initial == '1',
          _ => initial,
        };
        final label = field.defaultLabel;
        if (label != null) _labels[field.key] = label;
      }
    }
    _dropHidden();
  }

  /// Builds a controller from a `request_options` row (or any map with
  /// `fields`, `attachments`, `settings`, `subject_mode`). [existing] is the
  /// `get_request` map of a request being edited: its values and subject are
  /// loaded and no defaults are applied.
  factory RequestFormController.fromType(
    Map<String, dynamic> type, {
    Map<String, dynamic>? existing,
    RequestFieldOptionsLoader? loadOptions,
    RequestFilePicker? filePicker,
    String idPrefix = '',
    bool showRequiredMarks = false,
    TextEditingController? subject,
  }) {
    final controller = RequestFormController(
      fields: [
        for (final raw in type['fields'] as List? ?? const [])
          if (raw is Map) WorkflowFormFieldDefinition.fromMap(raw)
      ],
      initialValues: existing == null
          ? const {}
          : Map<String, dynamic>.from(existing['values'] as Map? ?? {}),
      applyDefaults: existing == null,
      limits: RequestAttachmentLimits.fromMap(type['attachments']),
      loadOptions: loadOptions,
      filePicker: filePicker,
      idPrefix: idPrefix.isEmpty ? '${type['name'] ?? ''}' : idPrefix,
      showRequiredMarks: showRequiredMarks,
      settings: type['settings'] is Map
          ? Map<String, dynamic>.from(type['settings'] as Map)
          : const {},
      subjectMode: '${type['subject_mode'] ?? 'input'}'.isEmpty
          ? 'input'
          : '${type['subject_mode'] ?? 'input'}',
      subjectLabel: '${type['subject_label'] ?? ''}'.isEmpty
          ? 'عنوان درخواست'
          : '${type['subject_label']}',
      existingAttachments: [
        for (final row in existing?['attachments'] as List? ?? const [])
          if (row is Map) RequestAttachment.fromMap(row)
      ],
      subject: subject,
    );
    if (existing != null && controller.subject.text.isEmpty) {
      controller.subject.text = '${existing['subject'] ?? ''}';
    }
    return controller;
  }

  /// Forwards to [repository.fieldOptions] passing only the arguments in use
  /// (`itemCode` for `UOM`, else `txt`; `scope` when set).
  static RequestFieldOptionsLoader loaderFor(
          GenericRequestRepository repository) =>
      (fieldType, {String txt = '', String? itemCode, String? scope}) {
        if (itemCode != null) {
          return scope == null
              ? repository.fieldOptions(fieldType, itemCode: itemCode)
              : repository.fieldOptions(fieldType,
                  itemCode: itemCode, scope: scope);
        }
        return scope == null
            ? repository.fieldOptions(fieldType, txt: txt)
            : repository.fieldOptions(fieldType, txt: txt, scope: scope);
      };

  final List<WorkflowFormFieldDefinition> fields;
  final RequestAttachmentLimits limits;

  /// Loads choices for User, Department, System Select and Item fields.
  final RequestFieldOptionsLoader? loadOptions;

  /// File chooser for field and row files; null uses the system picker.
  final RequestFilePicker? filePicker;

  /// Prefix of the widget keys (`ValueKey('<idPrefix>:<field key>')`).
  final String idPrefix;

  /// Appends « *» to the label of required fields (the mockups do).
  final bool showRequiredMarks;

  /// `settings` of the request type (`cost_center_required`, ...).
  final Map<String, dynamic> settings;

  /// `input` (the user types the subject) or `generated` (the server does).
  final String subjectMode;
  final String subjectLabel;

  /// Files of the request being edited.
  final List<RequestAttachment> existingAttachments;

  /// The subject text. Only used when [subjectMode] is `input`.
  final TextEditingController subject;
  final bool _ownsSubject;

  late final Map<String, dynamic> _initial;
  final Map<String, dynamic> _values = {};
  final Map<String, String> _labels = {};
  final Map<String, String> _autoText = {};
  final Map<String, String> _errors = {};
  final Map<String, String> _externalErrors = {};
  final List<RequestAttachmentDraft> _drafts = [];
  final Set<String> _removedExisting = {};
  int _refCounter = 0;
  String? _subjectError;

  // Fields ---------------------------------------------------------------

  WorkflowFormFieldDefinition? field(String key) =>
      fields.where((field) => field.key == key).firstOrNull;

  /// Whether [key] is shown: its `visible_when` holds for the current values
  /// (a controlling field that is itself hidden counts as empty).
  bool isVisible(String key, {int depth = 0}) {
    final definition = field(key);
    final rule = definition?.visibleWhen;
    if (rule == null) return true;
    if (depth > fields.length) return false;
    final controlling =
        isVisible(rule.field, depth: depth + 1) ? _values[rule.field] : null;
    return rule.matches(controlling);
  }

  /// Whether the user must fill [field]: `required`, or the company setting
  /// named by `required_by_setting`.
  bool isRequired(WorkflowFormFieldDefinition field) =>
      field.required ||
      (field.requiredBySetting == 'request_cost_center_required' &&
          settings['cost_center_required'] == true);

  Object? value(String key) => _values[key];

  /// The label shown for a link field's stored value, when known.
  String? labelFor(String key) => _labels[key];

  /// Sets a value (and the label to show for it) and drops the values of
  /// fields that `visible_when` now hides.
  void setValue(String key, Object? value, {String? label}) {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
    if (label == null) {
      _labels.remove(key);
    } else {
      _labels[key] = label;
    }
    _errors.remove(key);
    _dropHidden();
    notifyListeners();
  }

  void _dropHidden() {
    var changed = true;
    while (changed) {
      changed = false;
      for (final field in fields) {
        if (!isVisible(field.key) && _values.containsKey(field.key)) {
          _values.remove(field.key);
          _labels.remove(field.key);
          _errors.remove(field.key);
          changed = true;
        }
      }
    }
  }

  /// Display text of an `Auto` field set by the form (e.g. the leave
  /// duration), or null.
  String? autoText(String key) => _autoText[key];

  void setAutoText(String key, String? text) {
    if (text == null || text.isEmpty) {
      _autoText.remove(key);
    } else {
      _autoText[key] = text;
    }
    notifyListeners();
  }

  // Validation -------------------------------------------------------------

  /// The error of [key] (from [validate] or [setExternalError]).
  String? errorFor(String key) => _externalErrors[key] ?? _errors[key];

  String? get subjectError => _subjectError;

  /// Errors set by the form itself (e.g. a server leave preview), kept until
  /// cleared and counted by [validate].
  void setExternalError(String key, String? message) {
    if (message == null || message.isEmpty) {
      if (_externalErrors.remove(key) == null) return;
    } else {
      _externalErrors[key] = message;
    }
    notifyListeners();
  }

  bool get hasExternalErrors =>
      _externalErrors.keys.any((key) => isVisible(key));

  /// Checks every visible field (hidden and `Auto` fields are skipped) and the
  /// subject; the messages are then shown by the widgets. Returns whether the
  /// form is valid.
  bool validate() {
    _errors.clear();
    for (final field in fields) {
      if (field.type == 'Auto' || !isVisible(field.key)) continue;
      final message = _validateField(field);
      if (message != null) _errors[field.key] = message;
    }
    _subjectError = null;
    if (subjectMode == 'input') {
      final length = subject.text.trim().length;
      if (length < 3 || length > 140) {
        _subjectError = 'عنوان ۳ تا ۱۴۰ نویسه باشد.';
      }
    }
    notifyListeners();
    return _errors.isEmpty && _subjectError == null && !hasExternalErrors;
  }

  /// The first visible field (in form order) that has an error.
  String? get firstErrorKey => fields
      .where((field) => errorFor(field.key) != null)
      .map((field) => field.key)
      .firstOrNull;

  static final _timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
  static final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static bool _isEmpty(Object? value) =>
      value == null ||
      (value is String && value.trim().isEmpty) ||
      (value is List && value.isEmpty);

  /// A number typed with Persian or Latin digits, or null.
  static num? parseNumber(Object? value) {
    if (value is num) return value.isFinite ? value : null;
    final text = toLatinDigits('${value ?? ''}')
        .trim()
        .replaceAll('٫', '.')
        .replaceAll('٬', '')
        .replaceAll(',', '');
    final number = num.tryParse(text);
    return number != null && number.isFinite ? number : null;
  }

  String? _validateField(WorkflowFormFieldDefinition field) {
    final value = _values[field.key];
    final required = isRequired(field);
    switch (field.type) {
      case 'Checkbox':
        return required && value == null ? requestRequiredMessage : null;
      case 'Item Table':
        final rows = value is List ? value : const [];
        final min = field.rowOptions?.minRows ?? (required ? 1 : 0);
        final max = field.rowOptions?.maxRows ?? 100;
        if (rows.length < min || (required && rows.isEmpty)) {
          return 'حداقل یک ردیف کالا لازم است.';
        }
        if (rows.length > max) {
          return 'حداکثر ${toPersianDigits(max)} ردیف مجاز است.';
        }
        for (final row in rows) {
          final qty = parseNumber(row is Map ? row['qty'] : null);
          if (qty == null || qty <= 0) {
            return 'مقدار هر ردیف باید بیشتر از صفر باشد.';
          }
        }
        return null;
      case 'Table':
        return null; // Validated by the table widget itself.
    }
    if (_isEmpty(value)) return required ? requestRequiredMessage : null;
    switch (field.type) {
      case 'Number' || 'Currency':
        return parseNumber(value) == null ? 'عدد معتبر وارد کنید.' : null;
      case 'Date':
        final text = '$value';
        final date = DateTime.tryParse(text);
        if (!_datePattern.hasMatch(text) ||
            date == null ||
            date.toIso8601String().substring(0, 10) != text) {
          return 'تاریخ معتبر را از تقویم شمسی انتخاب کنید.';
        }
        if (field.minDate == 'today' && value != _initial[field.key]) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          if (date.isBefore(today)) return 'تاریخ نمی‌تواند در گذشته باشد.';
        }
        return null;
      case 'Time':
        return _timePattern.hasMatch('$value')
            ? null
            : 'ساعت معتبر (۲۴ ساعته) وارد کنید.';
      case 'Choice':
        return field.options.isNotEmpty && !field.options.contains('$value')
            ? 'گزینه‌ها تغییر کرده‌اند؛ انتخاب را اصلاح کنید.'
            : null;
      case 'Multi Choice':
        return value is List && value.any((v) => !field.options.contains(v))
            ? 'گزینه‌ها تغییر کرده‌اند؛ انتخاب را اصلاح کنید.'
            : null;
      case 'Attachment':
        return _referenceExists('$value')
            ? null
            : 'فایل انتخاب‌شده دیگر موجود نیست.';
      case 'Short Text' || 'Long Text':
        final max = field.maxLength;
        return max != null && '$value'.length > max
            ? 'حداکثر ${toPersianDigits(max)} نویسه مجاز است.'
            : null;
    }
    return null;
  }

  // Payload ----------------------------------------------------------------

  static const _rowInputKeys = [
    'item_code',
    'qty',
    'uom',
    'description',
    'note',
    'attachment'
  ];

  /// The `values` of `create_request` / `update_request`: visible, non-empty
  /// fields only. `Auto` fields and hidden fields are omitted, numbers are
  /// numbers, item rows keep only the row input keys.
  Map<String, dynamic> payloadValues() {
    final result = <String, dynamic>{};
    for (final field in fields) {
      if (field.type == 'Auto' || !isVisible(field.key)) continue;
      final value = _values[field.key];
      switch (field.type) {
        case 'Checkbox':
          if (value is bool) result[field.key] = value;
        case 'Number' || 'Currency':
          if (_isEmpty(value)) continue;
          result[field.key] = parseNumber(value) ?? value;
        case 'Item Table':
          final rows = [
            for (final row in value as List? ?? const [])
              if (row is Map)
                {
                  for (final key in _rowInputKeys)
                    if (!_isEmpty(row[key]))
                      key: key == 'qty'
                          ? parseNumber(row[key]) ?? row[key]
                          : row[key]
                }
          ];
          if (rows.isNotEmpty) result[field.key] = rows;
        case 'Table':
          final rows = [
            for (final row in value as List? ?? const [])
              if (row is Map) Map<String, dynamic>.from(row)
          ];
          if (rows.isNotEmpty) result[field.key] = rows;
        default:
          if (_isEmpty(value)) continue;
          result[field.key] = value is String ? value.trim() : value;
      }
    }
    return result;
  }

  // Files ------------------------------------------------------------------

  List<RequestAttachmentDraft> get drafts => List.unmodifiable(_drafts);

  RequestAttachmentDraft? draft(String ref) =>
      _drafts.where((draft) => draft.ref == ref).firstOrNull;

  /// New files not tied to a field or an item row.
  List<RequestAttachmentDraft> get generalDrafts => [
        for (final draft in _drafts)
          if (draft.general) draft
      ];

  /// Files of the request being edited that were not removed.
  List<RequestAttachment> get keptExistingAttachments => [
        for (final file in existingAttachments)
          if (!_removedExisting.contains(file.name)) file
      ];

  /// File names to send as `remove_attachments`.
  List<String> get removedAttachmentNames => _removedExisting.toList();

  /// Why a file of [filename] and [size] bytes cannot be added now, or null.
  String? attachmentError(String filename, int size) {
    final dot = filename.lastIndexOf('.');
    final extension = dot < 0 ? '' : filename.substring(dot + 1).toLowerCase();
    if (!limits.extensions.contains(extension)) {
      return 'فرمت فایل مجاز نیست؛ فرمت‌های مجاز: ${limits.extensionsLabel}.';
    }
    if (size > limits.maxBytes) {
      return 'حجم هر فایل حداکثر ${toPersianDigits(limits.maxMb)} مگابایت است.';
    }
    final count = _drafts.length + keptExistingAttachments.length;
    if (count + 1 > limits.maxFiles) {
      return 'حداکثر ${toPersianDigits(limits.maxFiles)} فایل می‌توانید پیوست کنید.';
    }
    final total = _drafts.fold<int>(0, (sum, draft) => sum + draft.size) +
        keptExistingAttachments.fold<int>(0, (sum, file) => sum + file.size);
    if (total + size > limits.maxTotalBytes) {
      return 'مجموع حجم فایل‌ها حداکثر ${toPersianDigits(limits.maxTotalMb)} مگابایت است.';
    }
    return null;
  }

  /// Adds a file and returns its unique reference (`att-1`). A general file is
  /// always uploaded; pass `general: false` for a field or row file, which is
  /// uploaded only while a value references it (`attachment:<ref>`). Throws
  /// [RequestAttachmentException] when it breaks the limits.
  String addAttachment(
      {required String filename,
      required List<int> bytes,
      bool general = true}) {
    final message = attachmentError(filename, bytes.length);
    if (message != null) throw RequestAttachmentException(message);
    final ref = 'att-${++_refCounter}';
    _drafts.add(RequestAttachmentDraft(
        ref: ref,
        filename: filename,
        bytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
        general: general));
    notifyListeners();
    return ref;
  }

  /// Removes a new file and clears the values that referenced it.
  void removeAttachment(String ref) {
    final before = _drafts.length;
    _drafts.removeWhere((draft) => draft.ref == ref);
    if (_drafts.length == before) return;
    _clearReferences('attachment:$ref');
    notifyListeners();
  }

  /// Marks a file of the edited request for removal and clears the values that
  /// pointed at it.
  void removeExistingAttachment(String name) {
    final file = existingAttachments.where((f) => f.name == name).firstOrNull;
    if (file == null || !_removedExisting.add(name)) return;
    if (file.fileUrl.isNotEmpty) _clearReferences(file.fileUrl);
    notifyListeners();
  }

  void _clearReferences(String reference) {
    for (final key in _values.keys.toList()) {
      final value = _values[key];
      if (value == reference) {
        _values.remove(key);
      } else if (value is List) {
        for (final row in value) {
          if (row is Map && row['attachment'] == reference) {
            row.remove('attachment');
          }
        }
      }
    }
  }

  /// The filename to show for a stored file reference.
  String? attachmentLabel(Object? reference) {
    final text = '$reference';
    if (text.startsWith('attachment:')) {
      final ref = text.substring('attachment:'.length);
      return draft(ref)?.filename ?? ref;
    }
    return existingAttachments
            .where((file) => file.fileUrl == text)
            .firstOrNull
            ?.filename ??
        (text.isEmpty ? null : text.split('/').last);
  }

  bool _referenceExists(String reference) {
    if (reference.startsWith('attachment:')) {
      return draft(reference.substring('attachment:'.length)) != null;
    }
    return keptExistingAttachments.any((file) => file.fileUrl == reference) ||
        existingAttachments.every((file) => file.fileUrl != reference);
  }

  Set<String> _referencedRefs() {
    final refs = <String>{};
    void scan(Object? value) {
      if (value is String && value.startsWith('attachment:')) {
        refs.add(value.substring('attachment:'.length));
      } else if (value is List) {
        value.forEach(scan);
      } else if (value is Map) {
        value.values.forEach(scan);
      }
    }

    payloadValues().values.forEach(scan);
    return refs;
  }

  /// The `attachments` of `create_request` / `update_request`: every general
  /// file plus the field and row files a value still references, each as
  /// `{filename, content_base64, ref}`.
  List<Map<String, String>> attachmentUploads() {
    final referenced = _referencedRefs();
    return [
      for (final draft in _drafts)
        if (draft.general || referenced.contains(draft.ref))
          {
            'filename': draft.filename,
            'content_base64': base64Encode(draft.bytes),
            'ref': draft.ref,
          }
    ];
  }

  @override
  void dispose() {
    if (_ownsSubject) subject.dispose();
    super.dispose();
  }

  static Object? _copy(Object? value) => value is Map
      ? {for (final e in value.entries) e.key: _copy(e.value)}
      : value is List
          ? [for (final e in value) _copy(e)]
          : value;
}
