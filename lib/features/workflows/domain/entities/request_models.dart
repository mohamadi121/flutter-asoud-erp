/// Typed wrappers over the maps the request repository returns. The
/// repository itself stays map based; these are parsed on demand.
library;

import 'package:equatable/equatable.dart';

import '../../../../core/utils/jalali_date.dart';
import 'workflow_definition.dart';

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

String _text(Object? value) => value == null ? '' : '$value';

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

double? _double(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value');

bool _flag(Object? value) => value == true || value == 1 || value == '1';

/// The server's `status_key` (§5 of the contract), with its Persian label and
/// the list tab (`status_group`) it belongs to.
enum RequestStatusKey {
  submitted('submitted', 'ارسال شده', 'pending'),
  inReview('in_review', 'در حال بررسی', 'pending'),
  returned('returned', 'برگشت برای اصلاح', 'pending'),
  failed('failed', 'نیازمند بررسی', 'pending'),
  approved('approved', 'تأیید شده', 'approved'),
  rejected('rejected', 'رد شده', 'rejected'),
  cancelled('cancelled', 'لغو شده', ''),
  draft('draft', 'پیش‌نویس', '');

  const RequestStatusKey(this.serverKey, this.label, this.group);

  /// An unknown or empty key reads as [submitted].
  factory RequestStatusKey.fromServer(String? key) =>
      values.firstWhere((value) => value.serverKey == key,
          orElse: () => RequestStatusKey.submitted);

  /// The key of a legacy row that has only the instance `status`.
  factory RequestStatusKey.fromLegacy(String? status) => switch (status) {
        'Completed' => RequestStatusKey.approved,
        'Rejected' => RequestStatusKey.rejected,
        'Cancelled' => RequestStatusKey.cancelled,
        'Failed' => RequestStatusKey.failed,
        'Draft' => RequestStatusKey.draft,
        _ => RequestStatusKey.submitted,
      };

  /// `status_key` when present, else the legacy `status`.
  factory RequestStatusKey.fromMap(Map<dynamic, dynamic> map) =>
      isKnown(_text(map['status_key']))
          ? RequestStatusKey.fromServer(_text(map['status_key']))
          : RequestStatusKey.fromLegacy(_text(map['status']));

  /// Whether [key] is a known server status key.
  static bool isKnown(String? key) =>
      values.any((value) => value.serverKey == key);

  /// Value of `status_key` on the wire.
  final String serverKey;
  final String label;

  /// `pending`, `approved`, `rejected`, or empty (shown only in «همه»).
  final String group;
}

/// One row of `list_my_requests` (or a local outbox / preview row).
class RequestSummary extends Equatable {
  const RequestSummary({
    required this.name,
    required this.number,
    this.templateKey = '',
    this.subject = '',
    this.requestType = '',
    this.requesterName = '',
    this.creation = '',
    this.requiredBy = '',
    this.priority = '',
    this.statusKey = RequestStatusKey.submitted,
    this.statusLabel = '',
    this.statusGroup = 'pending',
    this.itemCount = 0,
    this.attachmentCount = 0,
    this.summary = const {},
    this.pendingSync = false,
    this.localPreview = false,
    this.isSample = false,
    this.raw = const {},
  });

  factory RequestSummary.fromMap(Map<dynamic, dynamic> source) {
    final map = _map(source);
    final pendingSync = _flag(map['pending_sync']);
    final key = RequestStatusKey.fromMap(map);
    final group = _text(map['status_group']);
    final label = _text(map['status_label']);
    return RequestSummary(
      name: _text(map['name']),
      number: _text(map['number']).isNotEmpty
          ? _text(map['number'])
          : _text(map['local_number']).isNotEmpty
              ? _text(map['local_number'])
              : pendingSync
                  ? '—'
                  : _text(map['name']),
      templateKey: _text(map['template_key']),
      subject: _text(map['subject']),
      requestType: _text(map['request_type']),
      requesterName: _text(map['requester_name']),
      creation: _text(map['creation']),
      requiredBy: _text(map['required_by']),
      priority: _text(map['priority']),
      statusKey: key,
      statusLabel: label.isNotEmpty ? label : key.label,
      statusGroup: group.isNotEmpty || map.containsKey('status_group')
          ? group
          : key.group,
      itemCount: _int(map['item_count']),
      attachmentCount: _int(map['attachment_count']),
      summary: _map(map['summary']),
      pendingSync: pendingSync,
      localPreview: _flag(map['local_preview']),
      isSample: _flag(map['is_sample']),
      raw: map,
    );
  }

  final String name, number, templateKey, subject, requestType, requesterName;
  final String creation, requiredBy, priority;
  final RequestStatusKey statusKey;
  final String statusLabel, statusGroup;
  final int itemCount, attachmentCount;

  /// Template specific card data (§4.6), e.g. the leave dates and duration.
  final Map<String, dynamic> summary;

  /// Client-only: saved in the outbox, not on the server yet.
  final bool pendingSync;

  /// Client-only: saved in the offline preview, never sent.
  final bool localPreview;
  final bool isSample;

  /// The row as the repository returned it (for `RequestStatusChip`).
  final Map<String, dynamic> raw;

  @override
  List<Object?> get props => [
        name,
        number,
        templateKey,
        subject,
        requestType,
        requesterName,
        creation,
        requiredBy,
        priority,
        statusKey,
        statusLabel,
        statusGroup,
        itemCount,
        attachmentCount,
        summary,
        pendingSync,
        localPreview,
        isSample,
      ];
}

/// A page of `list_my_requests` with the tab counts of `meta.counts`.
class RequestListPage extends Equatable {
  const RequestListPage({
    required this.items,
    this.total = 0,
    this.offset = 0,
    this.counts = const {},
    this.localCount = 0,
  });

  /// An empty first page.
  const RequestListPage.empty()
      : items = const [],
        total = 0,
        offset = 0,
        localCount = 0,
        counts = const {'all': 0, 'pending': 0, 'approved': 0, 'rejected': 0};

  final List<RequestSummary> items;
  final int total, offset;

  /// How many of [items] come from this device's outbox (first page only);
  /// they are included in [total] but are not rows of the server list.
  final int localCount;

  /// Keys `all`, `pending`, `approved`, `rejected`.
  final Map<String, int> counts;

  int count(String group) => counts[group] ?? 0;

  bool get hasMore => offset + items.length - localCount < total - localCount;

  @override
  List<Object?> get props => [items, total, offset, counts, localCount];
}

class RequestAttachment extends Equatable {
  const RequestAttachment({
    required this.name,
    required this.filename,
    this.fileUrl = '',
    this.size = 0,
    this.contentType = '',
    this.isImage = false,
    this.scope = 'general',
    this.isSample = false,
  });

  factory RequestAttachment.fromMap(Map<dynamic, dynamic> source) {
    final map = _map(source);
    final filename = _text(map['filename']);
    final contentType = _text(map['content_type']);
    return RequestAttachment(
      name: _text(map['name']),
      filename: filename,
      fileUrl: _text(map['file_url']),
      size: _int(map['size']),
      contentType: contentType,
      isImage: map.containsKey('is_image')
          ? _flag(map['is_image'])
          : contentType.startsWith('image/'),
      scope: _text(map['scope']).isEmpty ? 'general' : _text(map['scope']),
      isSample: _flag(map['is_sample']),
    );
  }

  final String name, filename, fileUrl, contentType, scope;
  final int size;
  final bool isImage, isSample;

  /// `general`, `field:<key>` or `row:<field_key>:<index>`.
  bool get isGeneral => scope == 'general';
  bool get isRowFile => scope.startsWith('row:');

  /// The item row index of a `row:<field>:<index>` file.
  int? get rowIndex => isRowFile ? int.tryParse(scope.split(':').last) : null;

  /// The field key of a `row:<field>:<index>` file.
  String? get rowField {
    final parts = scope.split(':');
    return isRowFile && parts.length >= 3 ? parts[1] : null;
  }

  @override
  List<Object?> get props =>
      [name, filename, fileUrl, size, contentType, isImage, scope, isSample];
}

class RequestItemRow extends Equatable {
  const RequestItemRow({
    required this.itemCode,
    this.itemName = '',
    this.qty,
    this.uom = '',
    this.description = '',
    this.note = '',
    this.attachmentRef,
    this.attachmentUrl = '',
  });

  factory RequestItemRow.fromMap(Map<dynamic, dynamic> source) {
    final map = _map(source);
    final ref = map['attachment_ref'];
    return RequestItemRow(
      itemCode: _text(map['item_code']),
      itemName: _text(map['item_name']),
      qty:
          map['qty'] is num ? map['qty'] as num : num.tryParse('${map['qty']}'),
      uom: _text(map['uom']),
      description: _text(map['description']),
      note: _text(map['note']),
      attachmentRef: ref is Map ? RequestAttachment.fromMap(ref) : null,
      attachmentUrl: _text(map['attachment']),
    );
  }

  final String itemCode, itemName, uom, description, note, attachmentUrl;
  final num? qty;

  /// `{name, filename, is_image}` added by the server for a row file.
  final RequestAttachment? attachmentRef;

  String get title => itemName.isNotEmpty ? itemName : itemCode;

  @override
  List<Object?> get props => [
        itemCode,
        itemName,
        qty,
        uom,
        description,
        note,
        attachmentRef,
        attachmentUrl
      ];
}

/// The native ERPNext document created after approval (`native` of §4.7).
class RequestNative extends Equatable {
  const RequestNative(
      {this.doctype = '', this.name = '', this.status = '', this.error = ''});

  factory RequestNative.fromMap(Object? source) {
    final map = _map(source);
    return RequestNative(
      doctype: _text(map['doctype']),
      name: _text(map['name']),
      status: _text(map['status']),
      error: _text(map['error']),
    );
  }

  final String doctype, name, status, error;

  /// `Pending`, `Created`, `Skipped` or `Failed`; empty for no native doc.
  bool get hasStatus => status.isNotEmpty;
  bool get failed => status == 'Failed';

  @override
  List<Object?> get props => [doctype, name, status, error];
}

/// `get_request` (§4.7).
class RequestDetail extends Equatable {
  const RequestDetail({
    required this.name,
    required this.number,
    this.company = '',
    this.templateKey = '',
    this.templateVersion = 0,
    this.workflowDefinition = '',
    this.requestType = '',
    this.subject = '',
    this.priority = '',
    this.requiredBy = '',
    this.project = '',
    this.department = '',
    this.owner = '',
    this.requesterName = '',
    this.requesterEmployee = '',
    this.creation = '',
    this.workflowInstance = '',
    this.status = '',
    this.displayStatus = '',
    this.statusKey = RequestStatusKey.submitted,
    this.statusLabel = '',
    this.statusGroup = 'pending',
    this.requestId = '',
    this.rejectionReason = '',
    this.canEdit = false,
    this.canCancel = false,
    this.itemCount = 0,
    this.attachmentCount = 0,
    this.commentCount = 0,
    this.values = const {},
    this.attachments = const [],
    this.fields = const [],
    this.native = const RequestNative(),
    this.pendingSync = false,
    this.localPreview = false,
    this.isSample = false,
    this.raw = const {},
  });

  factory RequestDetail.fromMap(Map<dynamic, dynamic> source) {
    final map = _map(source);
    final key = RequestStatusKey.fromMap(map);
    final label = _text(map['status_label']);
    final pendingSync = _flag(map['pending_sync']);
    final local = _text(map['local_number']);
    return RequestDetail(
      name: _text(map['name']),
      number: _text(map['number']).isNotEmpty
          ? _text(map['number'])
          : local.isNotEmpty
              ? local
              : pendingSync
                  ? '—'
                  : _text(map['name']),
      company: _text(map['company']),
      templateKey: _text(map['template_key']),
      templateVersion: _int(map['template_version']),
      workflowDefinition: _text(map['workflow_definition']),
      requestType: _text(map['request_type']),
      subject: _text(map['subject']),
      priority: _text(map['priority']),
      requiredBy: _text(map['required_by']),
      project: _text(map['project']),
      department: _text(map['department']),
      owner: _text(map['owner']),
      requesterName: _text(map['requester_name']),
      requesterEmployee: _text(map['requester_employee']),
      creation: _text(map['creation']),
      workflowInstance: _text(map['workflow_instance']),
      status: _text(map['status']),
      displayStatus: _text(map['display_status']),
      statusKey: key,
      statusLabel: label.isNotEmpty ? label : key.label,
      statusGroup: _text(map['status_group']).isNotEmpty
          ? _text(map['status_group'])
          : key.group,
      requestId: _text(map['request_id']),
      rejectionReason: _text(map['rejection_reason']),
      canEdit: _flag(map['can_edit']),
      canCancel: _flag(map['can_cancel']),
      itemCount: _int(map['item_count']),
      attachmentCount: _int(map['attachment_count']),
      commentCount: _int(map['comment_count']),
      values: _map(map['values']),
      attachments: [
        for (final row in map['attachments'] as List? ?? const [])
          if (row is Map) RequestAttachment.fromMap(row)
      ],
      fields: [
        for (final row in map['fields'] as List? ?? const [])
          if (row is Map) WorkflowFormFieldDefinition.fromMap(row)
      ],
      native: RequestNative.fromMap(map['native']),
      pendingSync: pendingSync,
      localPreview: _flag(map['local_preview']),
      isSample: _flag(map['is_sample']),
      raw: map,
    );
  }

  final String name, number, company, templateKey, workflowDefinition;
  final String requestType, subject, priority, requiredBy, project, department;
  final String owner, requesterName, requesterEmployee, creation;
  final String workflowInstance, status, displayStatus, requestId;
  final String rejectionReason, statusLabel, statusGroup;
  final int templateVersion, itemCount, attachmentCount, commentCount;
  final RequestStatusKey statusKey;
  final bool canEdit, canCancel, pendingSync, localPreview, isSample;
  final Map<String, dynamic> values;
  final List<RequestAttachment> attachments;
  final List<WorkflowFormFieldDefinition> fields;
  final RequestNative native;
  final Map<String, dynamic> raw;

  /// The rows of the request's «Item Table» field(s).
  List<RequestItemRow> get items {
    final tableKeys = {
      for (final field in fields)
        if (field.type == 'Item Table') field.key
    };
    return [
      for (final entry in values.entries)
        if (entry.value is List &&
            (tableKeys.contains(entry.key) ||
                (tableKeys.isEmpty &&
                    (entry.value as List)
                        .any((row) => row is Map && row['item_code'] != null))))
          for (final row in entry.value as List)
            if (row is Map) RequestItemRow.fromMap(row)
    ];
  }

  /// Files that are not tied to a field or an item row.
  List<RequestAttachment> get generalAttachments => [
        for (final file in attachments)
          if (file.isGeneral) file
      ];

  @override
  List<Object?> get props => [
        name,
        number,
        company,
        templateKey,
        templateVersion,
        workflowDefinition,
        requestType,
        subject,
        priority,
        requiredBy,
        project,
        department,
        owner,
        requesterName,
        requesterEmployee,
        creation,
        workflowInstance,
        status,
        displayStatus,
        statusKey,
        statusLabel,
        statusGroup,
        requestId,
        rejectionReason,
        canEdit,
        canCancel,
        itemCount,
        attachmentCount,
        commentCount,
        values,
        attachments,
        fields,
        native,
        pendingSync,
        localPreview,
        isSample,
      ];
}

/// A free comment of the «نظرات» thread.
class RequestComment extends Equatable {
  const RequestComment({
    required this.name,
    required this.content,
    this.author = '',
    this.authorName = '',
    this.creation = '',
    this.isMine = false,
    this.pending = false,
  });

  factory RequestComment.fromMap(Map<dynamic, dynamic> source) {
    final map = _map(source);
    return RequestComment(
      name: _text(map['name']),
      content: _text(map['content']),
      author: _text(map['author']),
      authorName: _text(map['author_name']),
      creation: _text(map['creation']),
      isMine: _flag(map['is_mine']),
      pending: _flag(map['pending']),
    );
  }

  final String name, content, author, authorName, creation;
  final bool isMine;

  /// Client-only: queued offline, shown with «در انتظار ارسال».
  final bool pending;

  String get displayName => authorName.isNotEmpty ? authorName : author;

  @override
  List<Object?> get props =>
      [name, content, author, authorName, creation, isMine, pending];
}

class LeaveBalanceCategory extends Equatable {
  const LeaveBalanceCategory({
    required this.category,
    required this.label,
    this.remainingDays = 0,
    this.availableDays = 0,
    this.pendingDays = 0,
  });

  factory LeaveBalanceCategory.fromMap(Map<dynamic, dynamic> source) {
    final map = _map(source);
    return LeaveBalanceCategory(
      category: _text(map['category']),
      label: _text(map['label']),
      remainingDays: _double(map['remaining_days']) ?? 0,
      availableDays: _double(map['available_days']) ?? 0,
      pendingDays: _double(map['pending_days']) ?? 0,
    );
  }

  /// `annual`, `sick`, `unpaid` or `other`.
  final String category, label;
  final double remainingDays, availableDays, pendingDays;

  @override
  List<Object?> get props =>
      [category, label, remainingDays, availableDays, pendingDays];
}

class LeaveBalanceType extends Equatable {
  const LeaveBalanceType({
    required this.leaveType,
    required this.category,
    this.label = '',
    this.isLwp = false,
    this.hasAllocation = false,
    this.totalLeaves = 0,
    this.leavesTaken = 0,
    this.hourlyTaken = 0,
    this.leavesPending = 0,
    this.remaining,
    this.available,
  });

  factory LeaveBalanceType.fromMap(Map<dynamic, dynamic> source) {
    final map = _map(source);
    return LeaveBalanceType(
      leaveType: _text(map['leave_type']),
      category: _text(map['category']),
      label: _text(map['label']),
      isLwp: _flag(map['is_lwp']),
      hasAllocation: _flag(map['has_allocation']),
      totalLeaves: _double(map['total_leaves']) ?? 0,
      leavesTaken: _double(map['leaves_taken']) ?? 0,
      hourlyTaken: _double(map['hourly_taken']) ?? 0,
      leavesPending: _double(map['leaves_pending']) ?? 0,
      remaining: _double(map['remaining']),
      available: _double(map['available']),
    );
  }

  final String leaveType, category, label;
  final bool isLwp, hasAllocation;
  final double totalLeaves, leavesTaken, hourlyTaken, leavesPending;

  /// `null` for leave without pay.
  final double? remaining, available;

  @override
  List<Object?> get props => [
        leaveType,
        category,
        label,
        isLwp,
        hasAllocation,
        totalLeaves,
        leavesTaken,
        hourlyTaken,
        leavesPending,
        remaining,
        available,
      ];
}

/// `get_leave_balance` (§4.11).
class LeaveBalance extends Equatable {
  const LeaveBalance({
    this.employee = '',
    this.asOf = '',
    this.dailyWorkingHours = 8,
    this.leaveApprover = '',
    this.categories = const [],
    this.leaveTypes = const [],
  });

  factory LeaveBalance.fromMap(Map<dynamic, dynamic> source) {
    final map = _map(source);
    return LeaveBalance(
      employee: _text(map['employee']),
      asOf: _text(map['as_of']),
      dailyWorkingHours: _double(map['daily_working_hours']) ?? 8,
      leaveApprover: _text(map['leave_approver']),
      categories: [
        for (final row in map['categories'] as List? ?? const [])
          if (row is Map) LeaveBalanceCategory.fromMap(row)
      ],
      leaveTypes: [
        for (final row in map['leave_types'] as List? ?? const [])
          if (row is Map) LeaveBalanceType.fromMap(row)
      ],
    );
  }

  final String employee, asOf, leaveApprover;
  final double dailyWorkingHours;
  final List<LeaveBalanceCategory> categories;
  final List<LeaveBalanceType> leaveTypes;

  LeaveBalanceCategory? category(String key) =>
      categories.where((row) => row.category == key).firstOrNull;

  LeaveBalanceType? leaveType(String name) =>
      leaveTypes.where((row) => row.leaveType == name).firstOrNull;

  @override
  List<Object?> get props => [
        employee,
        asOf,
        dailyWorkingHours,
        leaveApprover,
        categories,
        leaveTypes,
      ];
}

/// `duration` of a leave request (§3.6).
class LeaveDuration extends Equatable {
  const LeaveDuration(
      {this.unit = '', this.days, this.hours, this.dayEquivalent});

  factory LeaveDuration.fromMap(Object? source) {
    final map = _map(source);
    return LeaveDuration(
      unit: _text(map['unit']),
      days: _double(map['days']),
      hours: _double(map['hours']),
      dayEquivalent: _double(map['day_equivalent']),
    );
  }

  /// `day` or `hour`.
  final String unit;
  final double? days, hours, dayEquivalent;

  bool get isEmpty => unit.isEmpty;

  /// «۳ روز», «۴ ساعت», «۱٫۵ ساعت».
  String get label {
    final value = unit == 'hour' ? hours : days;
    if (value == null) return '';
    return '${formatPersianNumber(value)} ${unit == 'hour' ? 'ساعت' : 'روز'}';
  }

  Map<String, dynamic> toMap() => {
        'unit': unit,
        'days': days,
        'hours': hours,
        'day_equivalent': dayEquivalent,
      };

  @override
  List<Object?> get props => [unit, days, hours, dayEquivalent];
}

/// A number with Persian digits and the Persian decimal separator.
String formatPersianNumber(num value) {
  final text = value == value.roundToDouble()
      ? '${value.toInt()}'
      : '${double.parse(value.toStringAsFixed(2))}';
  return toPersianDigits(text).replaceAll('.', '٫');
}

class LeavePreviewError extends Equatable {
  const LeavePreviewError(
      {required this.code, this.field = '', this.message = ''});

  factory LeavePreviewError.fromMap(Map<dynamic, dynamic> source) {
    final map = _map(source);
    return LeavePreviewError(
      code: _text(map['code']),
      field: _text(map['field']),
      message: _text(map['message']),
    );
  }

  final String code, field, message;

  @override
  List<Object?> get props => [code, field, message];
}

class LeavePreviewBalance extends Equatable {
  const LeavePreviewBalance({
    this.leaveType = '',
    this.remainingBefore,
    this.requestedDays,
    this.remainingAfter,
    this.availableAfter,
  });

  factory LeavePreviewBalance.fromMap(Object? source) {
    final map = _map(source);
    return LeavePreviewBalance(
      leaveType: _text(map['leave_type']),
      remainingBefore: _double(map['remaining_before']),
      requestedDays: _double(map['requested_days']),
      remainingAfter: _double(map['remaining_after']),
      availableAfter: _double(map['available_after']),
    );
  }

  final String leaveType;
  final double? remainingBefore, requestedDays, remainingAfter, availableAfter;

  @override
  List<Object?> get props => [
        leaveType,
        remainingBefore,
        requestedDays,
        remainingAfter,
        availableAfter
      ];
}

/// `preview_leave_request` (§4.11). Business errors are data, not exceptions.
class LeavePreview extends Equatable {
  const LeavePreview({
    this.valid = false,
    this.errors = const [],
    this.duration = const LeaveDuration(),
    this.balance,
    this.holidaysExcluded = 0,
  });

  factory LeavePreview.fromMap(Map<dynamic, dynamic> source) {
    final map = _map(source);
    return LeavePreview(
      valid: _flag(map['valid']),
      errors: [
        for (final row in map['errors'] as List? ?? const [])
          if (row is Map) LeavePreviewError.fromMap(row)
      ],
      duration: LeaveDuration.fromMap(map['duration']),
      balance: map['balance'] is Map
          ? LeavePreviewBalance.fromMap(map['balance'])
          : null,
      holidaysExcluded: _int(map['holidays_excluded']),
    );
  }

  final bool valid;
  final List<LeavePreviewError> errors;
  final LeaveDuration duration;
  final LeavePreviewBalance? balance;
  final int holidaysExcluded;

  String? get firstMessage => errors.isEmpty ? null : errors.first.message;

  @override
  List<Object?> get props =>
      [valid, errors, duration, balance, holidaysExcluded];
}

const _linkScheme = 'asoud', _linkHost = 'request';

/// The copyable deep link of a request: `asoud://request/<name>`.
String requestLink(String name) =>
    '$_linkScheme://$_linkHost/${Uri.encodeComponent(name)}';

/// The request name of an `asoud://request/<name>` link, or null for any
/// other text.
String? parseRequestLink(String link) {
  final uri = Uri.tryParse(link.trim());
  if (uri == null ||
      uri.scheme != _linkScheme ||
      uri.host != _linkHost ||
      uri.pathSegments.length != 1) {
    return null;
  }
  final name = uri.pathSegments.single;
  return name.isEmpty ? null : name;
}
