import '../../workflows/domain/entities/request_models.dart' show RequestStatusKey;
import 'system_templates.dart';

/// Demo rows for the offline preview, reproducing the mockups
/// (CONTRACT §6.6). Every row carries the list keys (§4.6) and the detail keys
/// (§4.7) so one map serves `list`, `detail` and the cards. Dates are relative
/// to [now]; names keep the mockup numbers (`PR-1404-0023`, `LV-1404-0042` ...).

const demoRequesterUser = 'ali@asoud.test';
const demoRequesterName = 'علی محمدی';

String _date(DateTime day) => day.toIso8601String().substring(0, 10);

String _stamp(DateTime moment) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${_date(moment)} ${two(moment.hour)}:${two(moment.minute)}:00';
}

String _instanceStatus(String key) => switch (key) {
      'approved' => 'Completed',
      'rejected' => 'Rejected',
      _ => 'Running',
    };

const _priorityLabels = {'Normal': 'عادی', 'High': 'مهم', 'Urgent': 'فوری'};

Map<String, dynamic> _attachment(
  String name,
  String filename,
  int size,
  String type, {
  String scope = 'general',
}) =>
    {
      'name': name,
      'filename': filename,
      'file_url': '/private/files/$filename',
      'size': size,
      'content_type': type,
      'is_image': type.startsWith('image/'),
      'scope': scope,
    };

Map<String, dynamic> _base({
  required DateTime now,
  required String name,
  required String templateKey,
  required String subject,
  required String statusKey,
  required int createdDaysAgo,
  required Map<String, dynamic> values,
  required Map<String, dynamic> summary,
  required List<Map<String, dynamic>> attachments,
  String requesterName = demoRequesterName,
  String owner = demoRequesterUser,
  String priority = 'Normal',
  String? requiredBy,
  String project = '',
  String department = '',
  int itemCount = 0,
  String rejectionReason = '',
  String? nativeStatus,
}) {
  final creation = _stamp(DateTime(now.year, now.month, now.day, 10, 15)
      .subtract(Duration(days: createdDaysAgo)));
  final type = systemRequestType(templateKey);
  final open = statusKey == 'submitted' || statusKey == 'in_review';
  return {
    'name': name,
    'number': name,
    'company': type['company'],
    'workflow_definition': type['name'],
    'request_type': type['workflow_title'],
    'template_key': templateKey,
    'template_version': 1,
    'subject': subject,
    'priority': priority,
    'required_by': requiredBy,
    'project': project,
    'department': department,
    'workflow_instance': 'WFI-DEMO-$name',
    'status': _instanceStatus(statusKey),
    'display_status': '',
    'status_key': statusKey,
    'status_label': RequestStatusKey.fromServer(statusKey).label,
    'status_group': RequestStatusKey.fromServer(statusKey).group,
    'request_id': 'demo-$name',
    'owner': owner,
    'requester_name': requesterName,
    'requester_employee': 'HR-EMP-00001',
    'creation': creation,
    'item_count': itemCount,
    'attachment_count': attachments.length,
    'comment_count': 0,
    'summary': summary,
    'native_status': nativeStatus ?? '',
    'native': {
      'doctype': '',
      'name': '',
      'status': nativeStatus ?? '',
      'error': ''
    },
    'rejection_reason': rejectionReason,
    'can_edit': open,
    'can_cancel': open,
    'values': values,
    'attachments': attachments,
    'fields': type['fields'],
    'is_sample': true,
  };
}

Map<String, dynamic> _row({
  required String code,
  required String name,
  required num qty,
  required String uom,
  String description = '',
  String note = '',
  Map<String, dynamic>? file,
}) =>
    {
      'item_code': code,
      'item_name': name,
      'qty': qty,
      'uom': uom,
      'stock_uom': uom,
      'conversion_factor': 1,
      'stock_qty': qty,
      'is_stock_item': 1,
      'description': description,
      'note': note,
      if (file != null) ...{
        'attachment': file['file_url'],
        'attachment_ref': {
          'name': file['name'],
          'filename': file['filename'],
          'is_image': file['is_image'],
        },
      },
    };

Map<String, dynamic> _purchase(
  DateTime now, {
  required String name,
  required String subject,
  required String status,
  required int createdDaysAgo,
  required int neededInDays,
  required List<Map<String, dynamic>> items,
  required List<Map<String, dynamic>> attachments,
  String requesterName = demoRequesterName,
  String department = 'ICU - DEMO',
  String departmentLabel = 'بخش ICU',
  String project = '',
  String projectLabel = '',
  String priority = 'High',
  String reason = '',
  String rejectionReason = '',
}) {
  final needed = _date(now.add(Duration(days: neededInDays)));
  return _base(
    now: now,
    name: name,
    templateKey: 'purchase',
    subject: subject,
    statusKey: status,
    createdDaysAgo: createdDaysAgo,
    requesterName: requesterName,
    priority: priority,
    requiredBy: needed,
    project: project,
    department: department,
    itemCount: items.length,
    attachments: attachments,
    rejectionReason: rejectionReason,
    summary: {
      'org_unit': department,
      'org_unit_label': departmentLabel,
      'cost_center': 'MED - DEMO',
      'cost_center_label': 'تجهیزات پزشکی',
      'project': project,
      'project_label': projectLabel,
      'priority': priority,
      'priority_label': _priorityLabels[priority],
      'needed_date': needed,
    },
    values: {
      'requester': demoRequesterUser,
      'org_unit': department,
      'cost_center': 'MED - DEMO',
      'project': project.isEmpty ? null : project,
      'needed_date': needed,
      'priority': priority,
      'reason': reason,
      'items': items,
    },
  );
}

Map<String, dynamic> _supply(
  DateTime now, {
  required String name,
  required String subject,
  required String status,
  required int createdDaysAgo,
  required int neededInDays,
  required String method,
  required String supplier,
  required List<Map<String, dynamic>> items,
  required List<Map<String, dynamic>> attachments,
  String requesterName = demoRequesterName,
  String delivery = 'department:ICU - DEMO',
  String deliveryLabel = 'بخش ICU',
  String department = 'ICU - DEMO',
  String departmentLabel = 'بخش ICU',
  String priority = 'High',
  String reason = '',
  String rejectionReason = '',
}) {
  final needed = _date(now.add(Duration(days: neededInDays)));
  final methodLabel = {
    'Warehouse': 'از انبار',
    'Purchase': 'خرید',
    'Transfer': 'انتقال',
    'Contract': 'قرارداد',
    'Unspecified': 'نامشخص',
  }[method]!;
  return _base(
    now: now,
    name: name,
    templateKey: 'supply',
    subject: subject,
    statusKey: status,
    createdDaysAgo: createdDaysAgo,
    requesterName: requesterName,
    priority: priority,
    requiredBy: needed,
    department: department,
    itemCount: items.length,
    attachments: attachments,
    rejectionReason: rejectionReason,
    summary: {
      'org_unit': department,
      'org_unit_label': departmentLabel,
      'project': '',
      'project_label': '',
      'priority': priority,
      'priority_label': _priorityLabels[priority],
      'needed_date': needed,
      'delivery_location': delivery,
      'delivery_location_label': deliveryLabel,
      'supply_method': method,
      'supply_method_label': methodLabel,
    },
    values: {
      'requester': demoRequesterUser,
      'org_unit': department,
      'delivery_location': delivery,
      'needed_date': needed,
      'supply_method': method,
      'suggested_supplier': supplier,
      'priority': priority,
      'reason': reason,
      'items': items,
    },
  );
}

Map<String, dynamic> _leave(
  DateTime now, {
  required String name,
  required String leaveType,
  required String category,
  required String categoryLabel,
  required String kind,
  required String status,
  required int createdDaysAgo,
  required String fromDate,
  required String toDate,
  required Map<String, dynamic> duration,
  String? startTime,
  String? endTime,
  required String reason,
  List<Map<String, dynamic>> attachments = const [],
  String rejectionReason = '',
}) {
  final subject =
      'مرخصی $categoryLabel (${kind == 'Hourly' ? 'ساعتی' : 'روزانه'})';
  return _base(
    now: now,
    name: name,
    templateKey: 'leave',
    subject: subject,
    statusKey: status,
    createdDaysAgo: createdDaysAgo,
    requiredBy: fromDate,
    department: 'PREVIEW-IT',
    attachments: attachments,
    rejectionReason: rejectionReason,
    summary: {
      'leave_type': leaveType,
      'leave_type_label': categoryLabel,
      'category': category,
      'category_label': categoryLabel,
      'request_kind': kind,
      'from_date': fromDate,
      'to_date': toDate,
      'start_time': startTime,
      'end_time': endTime,
      'duration': duration,
      'location': 'Tehran',
      'location_label': 'تهران',
      'rejection_reason': rejectionReason,
    },
    values: {
      'requester': demoRequesterUser,
      'org_unit': 'PREVIEW-IT',
      'leave_type': leaveType,
      'request_kind': kind,
      if (kind == 'Daily') ...{'start_date': fromDate, 'end_date': toDate},
      if (kind == 'Hourly') ...{
        'leave_date': fromDate,
        'start_time': startTime,
        'end_time': endTime,
      },
      'duration': duration,
      'location': 'Tehran',
      'reason': reason,
    },
  );
}

Map<String, dynamic> _days(num days) => {
      'unit': 'day',
      'days': days.toDouble(),
      'hours': null,
      'day_equivalent': days.toDouble()
    };

Map<String, dynamic> _hours(num hours, {double daily = 8}) => {
      'unit': 'hour',
      'days': null,
      'hours': hours.toDouble(),
      'day_equivalent': double.parse((hours / daily).toStringAsFixed(4)),
    };

/// All demo requests of the three templates, newest first.
List<Map<String, dynamic>> demoTemplateRequests(DateTime now) {
  final pdf = _attachment(
      'demo-att-1', 'لیست مشخصات فنی.pdf', 1258291, 'application/pdf');
  final monitorImage = _attachment(
      'demo-att-2', 'monitor-xs.png', 18211, 'image/png',
      scope: 'row:items:0');
  final items = [
    _row(
        code: 'MON-XS',
        name: 'مانیتور بیمارستانی مدل XS',
        qty: 2,
        uom: 'عدد',
        file: monitorImage),
    _row(
        code: 'SPO2-SENSOR',
        name: 'سنسور اکسیژن SpO2',
        qty: 5,
        uom: 'عدد',
        description: 'مدل اصلی'),
    _row(code: 'CABLE-5M', name: 'کابل اتصال ۵ متری', qty: 10, uom: 'متر'),
  ];
  final rows = <Map<String, dynamic>>[
    _purchase(now,
        name: 'PR-1404-0023',
        subject: 'خرید تجهیزات پزشکی بخش ICU',
        status: 'submitted',
        createdDaysAgo: 0,
        neededInDays: 14,
        items: items,
        attachments: [pdf, monitorImage],
        project: 'PRJ-ICU-1404',
        projectLabel: 'توسعه بخش ICU',
        reason:
            'تأمین تجهیزات مانیتورینگ علائم حیاتی طبق برنامه توسعه بخش ICU.'),
    _purchase(now,
        name: 'PR-1404-0022',
        subject: 'خرید لوازم مصرفی اداری',
        status: 'approved',
        createdDaysAgo: 2,
        neededInDays: 10,
        requesterName: 'سارا رسایی',
        department: 'ADM - DEMO',
        departmentLabel: 'امور اداری',
        priority: 'Normal',
        reason: 'تکمیل موجودی لوازم مصرفی دفاتر.',
        items: [
          for (var i = 0; i < 5; i++)
            _row(
                code: 'OFF-0${i + 1}',
                name: 'لوازم اداری ${i + 1}',
                qty: 10,
                uom: 'عدد'),
        ],
        attachments: [
          _attachment(
              'demo-att-3', 'price-list.pdf', 204800, 'application/pdf'),
          _attachment(
              'demo-att-4', 'invoice.xlsx', 51200, 'application/vnd.ms-excel'),
        ]),
    _purchase(now,
        name: 'PR-1404-0021',
        subject: 'کابل و متریال شبکه',
        status: 'submitted',
        createdDaysAgo: 4,
        neededInDays: 20,
        requesterName: 'مهدی گریمی',
        department: 'PREVIEW-IT',
        departmentLabel: 'فناوری اطلاعات',
        priority: 'Normal',
        reason: 'گسترش شبکه طبقه سوم.',
        items: [
          _row(code: 'NET-CAT6', name: 'کابل شبکه CAT6', qty: 100, uom: 'متر'),
          _row(code: 'NET-SW24', name: 'سوئیچ ۲۴ پورت', qty: 1, uom: 'عدد'),
        ],
        attachments: [
          _attachment(
              'demo-att-5', 'network-plan.pdf', 307200, 'application/pdf'),
        ]),
    _purchase(now,
        name: 'PR-1404-0020',
        subject: 'خرید مبلمان اداری',
        status: 'rejected',
        createdDaysAgo: 6,
        neededInDays: 30,
        department: 'ADM - DEMO',
        departmentLabel: 'امور اداری',
        priority: 'Normal',
        reason: 'تعویض مبلمان اتاق جلسات.',
        rejectionReason: 'بودجه سال جاری برای این ردیف تخصیص داده نشده است.',
        items: [
          for (var i = 0; i < 4; i++)
            _row(
                code: 'FUR-0${i + 1}',
                name: 'مبل اداری ${i + 1}',
                qty: 1,
                uom: 'عدد'),
        ],
        attachments: const []),
    _supply(now,
        name: 'SP-1404-0007',
        subject: 'تأمین تجهیزات پزشکی ICU',
        status: 'submitted',
        createdDaysAgo: 1,
        neededInDays: 14,
        method: 'Warehouse',
        supplier: 'نوید طب',
        reason: 'تأمین تجهیزات مانیتورینگ علائم حیاتی طبق برنامه توسعه.',
        items: [
          _row(
              code: 'MON-XS',
              name: 'مانیتور بیمارستانی مدل XS',
              qty: 2,
              uom: 'عدد',
              description: 'قابل استفاده در ICU'),
          _row(
              code: 'SPO2-SENSOR',
              name: 'سنسور اکسیژن SpO2',
              qty: 5,
              uom: 'عدد',
              description: 'مدل اصلی'),
          _row(
              code: 'CABLE-5M',
              name: 'کابل اتصال ۵ متری',
              qty: 10,
              uom: 'متر',
              description: 'قابل استفاده'),
        ],
        attachments: [
          pdf
        ]),
    _supply(now,
        name: 'SP-1404-0006',
        subject: 'تأمین خدمات نگهداری تجهیزات',
        status: 'approved',
        createdDaysAgo: 5,
        neededInDays: 12,
        method: 'Purchase',
        supplier: 'نوید طب',
        priority: 'Normal',
        delivery: 'warehouse:Stores - DEMO',
        deliveryLabel: 'انبار مرکزی',
        items: [
          {
            ..._row(
                code: 'SRV-MNT',
                name: 'خدمات نگهداری سالانه',
                qty: 1,
                uom: 'واحد'),
            'is_stock_item': 0,
          },
        ],
        attachments: const []),
    _leave(now,
        name: 'LV-1404-0042',
        leaveType: 'Casual Leave',
        category: 'annual',
        categoryLabel: 'سالانه',
        kind: 'Daily',
        status: 'approved',
        createdDaysAgo: 3,
        fromDate: _date(now.add(const Duration(days: 4))),
        toDate: _date(now.add(const Duration(days: 6))),
        duration: _days(3),
        reason: 'سفر شخصی به همراه خانواده'),
    _leave(now,
        name: 'LV-1404-0041',
        leaveType: 'Sick Leave',
        category: 'sick',
        categoryLabel: 'استعلاجی',
        kind: 'Hourly',
        status: 'submitted',
        createdDaysAgo: 1,
        fromDate: _date(now.add(const Duration(days: 2))),
        toDate: _date(now.add(const Duration(days: 2))),
        startTime: '10:00',
        endTime: '14:00',
        duration: _hours(4),
        reason: 'مراجعه به بیمارستان برای معاینه پزشک',
        attachments: [
          _attachment(
              'demo-att-6', 'برگه وقت پزشک.pdf', 1258291, 'application/pdf'),
        ]),
    _leave(now,
        name: 'LV-1404-0040',
        leaveType: 'Sick Leave',
        category: 'sick',
        categoryLabel: 'استعلاجی',
        kind: 'Daily',
        status: 'rejected',
        createdDaysAgo: 20,
        fromDate: _date(now.subtract(const Duration(days: 16))),
        toDate: _date(now.subtract(const Duration(days: 16))),
        duration: _days(1),
        reason: 'استراحت پزشکی',
        rejectionReason: 'به دلیل مدارک ناقص'),
    _leave(now,
        name: 'LV-1404-0039',
        leaveType: 'Casual Leave',
        category: 'annual',
        categoryLabel: 'سالانه',
        kind: 'Hourly',
        status: 'approved',
        createdDaysAgo: 30,
        fromDate: _date(now.subtract(const Duration(days: 25))),
        toDate: _date(now.subtract(const Duration(days: 25))),
        startTime: '13:00',
        endTime: '16:00',
        duration: _hours(3),
        reason: 'کار اداری شخصی'),
    _leave(now,
        name: 'LV-1404-0038',
        leaveType: 'Casual Leave',
        category: 'annual',
        categoryLabel: 'سالانه',
        kind: 'Daily',
        status: 'approved',
        createdDaysAgo: 45,
        fromDate: _date(now.subtract(const Duration(days: 40))),
        toDate: _date(now.subtract(const Duration(days: 36))),
        duration: _days(5),
        reason: 'مسافرت'),
  ];
  return [
    for (final row in rows)
      {
        ...row,
        'comment_count':
            demoTemplateComments(row['name'] as String, now).length,
      },
  ];
}

/// Demo comments of a demo request (empty for most rows).
List<Map<String, dynamic>> demoTemplateComments(String name, DateTime now) {
  if (name != 'PR-1404-0023' && name != 'SP-1404-0007') return const [];
  final moment = DateTime(now.year, now.month, now.day, 9, 30);
  return [
    {
      'name': 'demo-comment-$name',
      'content': 'مشخصات فنی پیوست شد؛ لطفاً بررسی بفرمایید.',
      'author': demoRequesterUser,
      'author_name': demoRequesterName,
      'creation': _stamp(moment),
      'is_mine': true,
    }
  ];
}
