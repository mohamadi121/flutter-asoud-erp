/// Data for the offline preview (no server): request types from the locally
/// designed workflows, sample masters, and a copy of the server's document
/// template catalog (`asoud_erp/services/document_templates.py`).
///
/// Everything built with these values is marked local and never presented as
/// an ERPNext transaction.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'demo/request_demo_data.dart';
import 'request_demo_source.dart';

/// Where [PreviewFallbackWorkflowRepository] keeps the locally designed workflows.
const previewDesignsKey = 'asoud_workflow_designs_v2';

Future<List<Map<String, dynamic>>> _designs() async {
  final raw =
      (await SharedPreferences.getInstance()).getString(previewDesignsKey);
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    return decoded is List
        ? decoded.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : const [];
  } catch (_) {
    return const [];
  }
}

/// The form fields of a locally designed request type: the user task right
/// after Start, like the server's `_form_stage`.
List<Map<String, dynamic>>? _formFields(Map<String, dynamic> design) {
  final stages = [
    for (final stage in design['stages'] as List? ?? const [])
      if (stage is Map) Map<String, dynamic>.from(stage)
  ];
  final start = stages.where((stage) => stage['type'] == 'start').firstOrNull;
  if (start == null) return null;
  final next = (design['transitions'] as List? ?? const [])
      .whereType<Map>()
      .where((edge) => edge['from'] == start['id'])
      .map((edge) => edge['to'])
      .firstOrNull;
  final form = stages.where((stage) => stage['id'] == next).firstOrNull;
  if (form == null || form['type'] != 'userTask') return null;
  final config = form['config'];
  return [
    for (final field
        in (config is Map ? config['form_fields'] : null) as List? ?? const [])
      if (field is Map) Map<String, dynamic>.from(field)
  ];
}

/// Request types available offline: those registered by
/// [RequestDemoRegistry] (the system templates), then locally designed ones,
/// then the demo types («شرکت نمونه آسود», each `is_sample: true`) when
/// nothing was designed yet.
Future<List<Map<String, dynamic>>> offlineRequestTypes() async {
  final designs = await _designs();
  final all = [...designs, if (designs.isEmpty) ...demoDesignMaps()];
  return [
    ...RequestDemoRegistry.requestTypes(),
    for (final design in all)
      if ((design['workflow'] as Map?)?['target_doctype'] ==
              'ASOUD Workflow Request' &&
          _formFields(design) != null)
        {
          'name': (design['workflow'] as Map)['id'],
          'workflow_title': (design['workflow'] as Map)['title'],
          'short_title': (design['workflow'] as Map)['short_title'] ?? '',
          'icon_key': (design['workflow'] as Map)['icon_key'] ?? '',
          'request_category': (design['workflow'] as Map)['category'] ?? '',
          'fields': _formFields(design),
          if (design['is_sample'] == true) 'is_sample': true,
        },
  ];
}

/// Custom fields of an offline request type (template value sources).
Future<List<Map<String, dynamic>>> offlineRequestFields(
    String? workflow) async {
  if (workflow == null || workflow.isEmpty) return const [];
  for (final type in await offlineRequestTypes()) {
    if (type['name'] == workflow) {
      return [
        for (final field in type['fields'] as List)
          Map<String, dynamic>.from(field as Map)
      ];
    }
  }
  return const [];
}

const _sampleOptions = <String, List<Map<String, dynamic>>>{
  'Item': [
    {
      'value': 'PREVIEW-LAPTOP',
      'label': 'لپ‌تاپ',
      'item_code': 'PREVIEW-LAPTOP',
      'item_name': 'لپ‌تاپ',
      'stock_uom': 'عدد',
      'is_stock_item': 1,
      'is_purchase_item': 1,
    },
    {
      'value': 'PREVIEW-MOUSE',
      'label': 'ماوس بی‌سیم',
      'item_code': 'PREVIEW-MOUSE',
      'item_name': 'ماوس بی‌سیم',
      'stock_uom': 'عدد',
      'is_stock_item': 1,
      'is_purchase_item': 1,
    },
    {
      'value': 'PREVIEW-PAPER',
      'label': 'کاغذ A4',
      'item_code': 'PREVIEW-PAPER',
      'item_name': 'کاغذ A4',
      'stock_uom': 'بسته',
      'is_stock_item': 1,
      'is_purchase_item': 1,
    },
    {
      'value': 'ICU-MON-01',
      'label': 'مانیتور ICU',
      'item_code': 'ICU-MON-01',
      'item_name': 'مانیتور ICU',
      'stock_uom': 'Nos',
      'is_stock_item': 1,
      'is_purchase_item': 1,
      'item_group': 'تجهیزات پزشکی',
    },
    {
      'value': 'MON-XS',
      'label': 'مانیتور بیمار مدل XS',
      'item_code': 'MON-XS',
      'item_name': 'مانیتور بیمار مدل XS',
      'stock_uom': 'Nos',
      'is_stock_item': 1,
      'is_purchase_item': 1,
      'item_group': 'تجهیزات پزشکی',
    },
    {
      'value': 'SPO2-SENSOR',
      'label': 'سنسور اکسیژن SpO2',
      'item_code': 'SPO2-SENSOR',
      'item_name': 'سنسور اکسیژن SpO2',
      'stock_uom': 'Nos',
      'is_stock_item': 1,
      'is_purchase_item': 1,
      'item_group': 'تجهیزات پزشکی',
    },
    {
      'value': 'CABLE-5M',
      'label': 'کابل اتصال ۵ متری',
      'item_code': 'CABLE-5M',
      'item_name': 'کابل اتصال ۵ متری',
      'stock_uom': 'Meter',
      'is_stock_item': 1,
      'is_purchase_item': 1,
      'item_group': 'ملزومات',
    },
    {
      'value': 'SVC-INSTALL',
      'label': 'خدمات نصب و راه‌اندازی',
      'item_code': 'SVC-INSTALL',
      'item_name': 'خدمات نصب و راه‌اندازی',
      'stock_uom': 'Nos',
      'is_stock_item': 0,
      'is_purchase_item': 0,
      'item_group': 'خدمات',
    },
  ],
  'User': [
    {'value': 'preview.manager@local', 'label': 'مدیر نمونه'},
    {'value': 'preview.user@local', 'label': 'کارشناس نمونه'},
  ],
  'Department': [
    {'value': 'PREVIEW-FINANCE', 'label': 'مالی و حسابداری'},
    {'value': 'PREVIEW-TRADE', 'label': 'بازرگانی'},
    {'value': 'PREVIEW-IT', 'label': 'فناوری اطلاعات'},
    {'value': 'ICU - DEMO', 'label': 'بخش ICU'},
  ],
  'Cost Center': [
    {'value': 'MED - DEMO', 'label': 'تجهیزات پزشکی'},
    {'value': 'ADM - DEMO', 'label': 'اداری و پشتیبانی'},
  ],
  'Project': [
    {'value': 'PRJ-ICU-1404', 'label': 'توسعه بخش ICU'},
    {'value': 'PRJ-LAB-1404', 'label': 'نوسازی آزمایشگاه'},
  ],
  'Warehouse': [
    {'value': 'Stores - DEMO', 'label': 'انبار مرکزی'},
    {'value': 'Med - DEMO', 'label': 'انبار تجهیزات پزشکی'},
  ],
  'Branch': [
    {'value': 'Tehran', 'label': 'تهران'},
    {'value': 'Karaj', 'label': 'کرج'},
  ],
  'Supplier': [
    {'value': 'SUP-0001', 'label': 'نوید طب'},
    {'value': 'SUP-0002', 'label': 'پارس تجهیز'},
  ],
  'Leave Type': [
    {
      'value': 'Casual Leave',
      'label': 'سالانه',
      'category': 'annual',
      'is_lwp': 0
    },
    {
      'value': 'Sick Leave',
      'label': 'استعلاجی',
      'category': 'sick',
      'is_lwp': 0
    },
    {
      'value': 'Leave Without Pay',
      'label': 'بدون حقوق',
      'category': 'unpaid',
      'is_lwp': 1
    },
    {'value': 'Other Leave', 'label': 'سایر', 'category': 'other', 'is_lwp': 0},
  ],
  'Delivery Location': [
    {
      'value': 'warehouse:Stores - DEMO',
      'label': 'انبار مرکزی',
      'kind': 'warehouse'
    },
    {
      'value': 'warehouse:Med - DEMO',
      'label': 'انبار تجهیزات پزشکی',
      'kind': 'warehouse'
    },
    {'value': 'branch:Tehran', 'label': 'تهران', 'kind': 'branch'},
    {'value': 'branch:Karaj', 'label': 'کرج', 'kind': 'branch'},
    {
      'value': 'department:ICU - DEMO',
      'label': 'بخش ICU',
      'kind': 'department'
    },
  ],
};

/// Sample choices for `request_field_options` while offline: the rows
/// registered by [RequestDemoRegistry] for [fieldType], else the built-in
/// samples. [scope] `purchase` limits `Item` to purchase items.
List<Map<String, dynamic>> offlineFieldOptions(String fieldType,
    {String txt = '', String? itemCode, String? scope}) {
  final all = RequestDemoRegistry.fieldOptions(fieldType) ??
      _sampleOptions[fieldType] ??
      const <Map<String, dynamic>>[];
  if (fieldType == 'UOM') {
    final item =
        (RequestDemoRegistry.fieldOptions('Item') ?? _sampleOptions['Item']!)
            .where((row) => row['value'] == itemCode)
            .firstOrNull;
    final uom = '${item?['stock_uom'] ?? 'عدد'}';
    final registered = RequestDemoRegistry.fieldOptions('UOM');
    if (registered != null) return registered;
    return [
      {'value': uom, 'label': uom, 'conversion_factor': 1},
      if (uom == 'Nos')
        {'value': 'Box', 'label': 'Box', 'conversion_factor': 10},
    ];
  }
  final needle = txt.trim().toLowerCase();
  return [
    for (final row in all)
      if ((needle.isEmpty ||
              '${row['label']}'.toLowerCase().contains(needle) ||
              '${row['value']}'.toLowerCase().contains(needle)) &&
          !(fieldType == 'Item' &&
              scope == 'purchase' &&
              (row['is_purchase_item'] == 0 ||
                  row['is_purchase_item'] == false)))
        row
  ];
}

/// Sample accounts, cost centers, projects and warehouses for templates.
const offlineLinkOptions = <String, List<Map<String, String>>>{
  'Account': [
    {'value': 'هزینه‌های عمومی - نمونه', 'label': 'هزینه‌های عمومی'},
    {'value': 'هزینه خرید - نمونه', 'label': 'هزینه خرید'},
    {'value': 'بستانکاران - نمونه', 'label': 'بستانکاران'},
    {'value': 'صندوق - نمونه', 'label': 'صندوق'},
    {'value': 'بانک - نمونه', 'label': 'بانک'},
  ],
  'Cost Center': [
    {'value': 'مرکز هزینه اصلی - نمونه', 'label': 'مرکز هزینه اصلی'},
  ],
  'Project': [
    {'value': 'پروژه نمونه', 'label': 'پروژه نمونه'},
  ],
  'Warehouse': [
    {'value': 'انبار مرکزی - نمونه', 'label': 'انبار مرکزی'},
  ],
};

const _requestBaseFields = [
  {'key': 'request_number', 'label': 'شماره درخواست', 'type': 'Text'},
  {'key': 'subject', 'label': 'عنوان درخواست', 'type': 'Text'},
  {'key': 'requested_on', 'label': 'تاریخ درخواست', 'type': 'Date'},
  {'key': 'requester', 'label': 'درخواست‌کننده', 'type': 'Text'},
  {
    'key': 'requester_department',
    'label': 'واحد درخواست‌دهنده',
    'type': 'Text'
  },
  {'key': 'description', 'label': 'شرح درخواست', 'type': 'Text'},
];

/// The `document_template_options` payload, built locally.
Future<Map<String, dynamic>> offlineTemplateOptions(String? workflow) async => {
      'modules': const [
        {
          'key': 'Finance',
          'label': 'مالی',
          'description': 'حسابداری و خزانه‌داری',
          'types': [
            {'key': 'Journal Entry', 'label': 'سند حسابداری', 'enabled': true},
            {'key': 'Receipt', 'label': 'دریافت', 'enabled': false},
            {'key': 'Payment', 'label': 'پرداخت', 'enabled': false},
          ],
        },
        {
          'key': 'Purchase',
          'label': 'خرید',
          'description': 'تأمین کالا و خدمات',
          'types': [
            {
              'key': 'Material Request',
              'label': 'درخواست خرید کالا',
              'enabled': true
            },
            {'key': 'Purchase Order', 'label': 'سفارش خرید', 'enabled': false},
          ],
        },
        {
          'key': 'Selling',
          'label': 'فروش',
          'description': 'مدیریت فروش و مشتریان',
          'types': []
        },
        {
          'key': 'Stock',
          'label': 'انبار',
          'description': 'مدیریت موجودی کالا',
          'types': []
        },
        {
          'key': 'HR',
          'label': 'منابع انسانی',
          'description': 'کارکنان و حقوق',
          'types': []
        },
        {
          'key': 'Admin',
          'label': 'خدمات اداری',
          'description': 'خدمات رفاهی و اداری',
          'types': []
        },
        {
          'key': 'IT',
          'label': 'IT و تجهیزات',
          'description': 'تجهیزات و زیرساخت',
          'types': []
        },
      ],
      'fields': const {
        'Journal Entry': [
          {
            'key': 'posting_date',
            'label': 'تاریخ سند',
            'type': 'Date',
            'required': true
          },
          {
            'key': 'title',
            'label': 'شرح سند',
            'type': 'Text',
            'required': true
          },
          {
            'key': 'amount',
            'label': 'مبلغ',
            'type': 'Currency',
            'required': true
          },
          {
            'key': 'debit_account',
            'label': 'حساب بدهکار',
            'type': 'Account',
            'required': true
          },
          {
            'key': 'credit_account',
            'label': 'حساب بستانکار',
            'type': 'Account',
            'required': true
          },
          {
            'key': 'cost_center',
            'label': 'مرکز هزینه',
            'type': 'Cost Center',
            'required': false
          },
          {
            'key': 'project',
            'label': 'پروژه',
            'type': 'Project',
            'required': false
          },
          {
            'key': 'user_remark',
            'label': 'توضیحات',
            'type': 'Text',
            'required': false
          },
        ],
        'Material Request': [
          {
            'key': 'transaction_date',
            'label': 'تاریخ درخواست',
            'type': 'Date',
            'required': true
          },
          {
            'key': 'schedule_date',
            'label': 'تاریخ نیاز',
            'type': 'Date',
            'required': true
          },
          {
            'key': 'items',
            'label': 'اقلام',
            'type': 'Item Table',
            'required': true
          },
          {
            'key': 'set_warehouse',
            'label': 'انبار مقصد',
            'type': 'Warehouse',
            'required': false
          },
        ],
      },
      'sources': {
        'request': [
          ..._requestBaseFields,
          for (final field in await offlineRequestFields(workflow))
            if (!_requestBaseFields.any((base) => base['key'] == field['key']))
              {
                'key': field['key'],
                'label': field['label'] ?? field['key'],
                'type': field['type'] ?? 'Short Text',
              },
        ],
        'user': const [
          {'key': 'initiator', 'label': 'کاربر درخواست‌کننده'},
          {'key': 'initiator_name', 'label': 'نام درخواست‌کننده'},
          {'key': 'initiator_department', 'label': 'واحد درخواست‌کننده'},
          {'key': 'actor', 'label': 'آخرین اقدام‌کننده'},
        ],
        'organization': const [
          {'key': 'company', 'label': 'نام شرکت'},
          {'key': 'default_currency', 'label': 'ارز پیش‌فرض'},
          {'key': 'cost_center', 'label': 'مرکز هزینه پیش‌فرض'},
        ],
        'system': const [
          {'key': 'today', 'label': 'تاریخ روز'},
          {'key': 'now', 'label': 'زمان جاری'},
          {'key': 'request_number', 'label': 'شماره درخواست'},
          {'key': 'instance', 'label': 'شماره فرایند'},
        ],
      },
      'placeholders': const [
        '{{RequestNo}}',
        '{{Subject}}',
        '{{Requester}}',
        '{{Today}}',
        '{{Company}}'
      ],
    };

/// The server's ready-made templates («الگوهای آماده»).
/// Seed data: `is_sample` rows are never offered for demo transfer.
const offlinePresets = <Map<String, dynamic>>[
  {
    'key': 'purchase_expense',
    'is_sample': true,
    'title': 'سند هزینه خرید',
    'description': 'ثبت سند حسابداری بر اساس هزینه خرید',
    'icon': 'cart',
    'module': 'Finance',
    'document_type': 'Journal Entry',
    'mapping': {
      'posting_date': {'source': 'system', 'value': 'today'},
      'title': {
        'source': 'fixed',
        'value': 'هزینه خرید بر اساس درخواست {{RequestNo}}'
      },
    },
  },
  {
    'key': 'supplier_payment',
    'is_sample': true,
    'title': 'پرداخت به تأمین‌کننده',
    'description': 'پرداخت وجه به تأمین‌کننده بر اساس سفارش خرید',
    'icon': 'payment',
    'module': 'Finance',
    'document_type': 'Journal Entry',
    'mapping': {
      'posting_date': {'source': 'system', 'value': 'today'},
      'title': {
        'source': 'fixed',
        'value': 'پرداخت بابت درخواست {{RequestNo}}'
      },
    },
  },
  {
    'key': 'general_expense',
    'is_sample': true,
    'title': 'سند هزینه عمومی',
    'description': 'هزینه‌های اداری و عمومی',
    'icon': 'chart',
    'module': 'Finance',
    'document_type': 'Journal Entry',
    'mapping': {
      'posting_date': {'source': 'system', 'value': 'today'},
      'title': {'source': 'fixed', 'value': 'هزینه عمومی {{Subject}}'},
    },
  },
  {
    'key': 'shipping_cost',
    'is_sample': true,
    'title': 'هزینه حمل و نقل',
    'description': 'ثبت هزینه حمل و نقل بر اساس درخواست خرید',
    'icon': 'truck',
    'module': 'Finance',
    'document_type': 'Journal Entry',
    'mapping': {
      'posting_date': {'source': 'system', 'value': 'today'},
      'title': {
        'source': 'fixed',
        'value': 'هزینه حمل بابت درخواست {{RequestNo}}'
      },
    },
  },
  {
    'key': 'purchase_material_request',
    'is_sample': true,
    'title': 'درخواست خرید کالا',
    'description': 'ایجاد درخواست خرید کالا در ERPNext از اقلام درخواست',
    'icon': 'box',
    'module': 'Purchase',
    'document_type': 'Material Request',
    'mapping': {
      'transaction_date': {'source': 'system', 'value': 'today'},
      'schedule_date': {'source': 'system', 'value': 'today'},
    },
  },
];

/// The sample leave balance of the offline preview (`get_leave_balance`
/// shape, §4.11): annual 12.5, sick 8, other 2 days, 8 working hours a day.
Map<String, dynamic> offlineLeaveBalance() => {
      'employee': 'PREVIEW-EMP-001',
      'as_of': DateTime.now().toIso8601String().substring(0, 10),
      'daily_working_hours': 8,
      'leave_approver': 'preview.manager@local',
      'categories': [
        {
          'category': 'annual',
          'label': 'سالانه',
          'remaining_days': 12.5,
          'available_days': 12.0,
          'pending_days': 0.5
        },
        {
          'category': 'sick',
          'label': 'استعلاجی',
          'remaining_days': 8.0,
          'available_days': 8.0,
          'pending_days': 0.0
        },
        {
          'category': 'other',
          'label': 'سایر',
          'remaining_days': 2.0,
          'available_days': 2.0,
          'pending_days': 0.0
        },
      ],
      'leave_types': [
        for (final row in _sampleOptions['Leave Type']!)
          {
            'leave_type': row['value'],
            'category': row['category'],
            'label': row['label'],
            'is_lwp': row['is_lwp'],
            'has_allocation': row['is_lwp'] != 1,
            'total_leaves': 0,
            'leaves_taken': 0,
            'hourly_taken': 0,
            'leaves_pending': 0,
            'remaining': switch (row['category']) {
              'annual' => 12.5,
              'sick' => 8.0,
              'other' => 2.0,
              _ => null,
            },
            'available': switch (row['category']) {
              'annual' => 12.0,
              'sick' => 8.0,
              'other' => 2.0,
              _ => null,
            },
          }
      ],
    };

const _leaveErrorMessages = {
  'INVALID_DATE_RANGE': 'تاریخ پایان نباید قبل از تاریخ شروع باشد.',
  'INVALID_TIME_RANGE': 'ساعت پایان باید بعد از ساعت شروع باشد.',
  'LEAVE_ALL_HOLIDAYS':
      'روزهای انتخاب‌شده همگی تعطیل هستند و نیازی به مرخصی نیست.',
  'HOURLY_ON_HOLIDAY': 'تاریخ انتخاب‌شده برای شما تعطیل است.',
  'HOURLY_EXCEEDS_DAY':
      'مدت مرخصی ساعتی نمی‌تواند از ساعت کاری روزانه بیشتر باشد.',
  'INSUFFICIENT_LEAVE_BALANCE': 'مانده مرخصی کافی نیست.',
};

int? _minutes(Object? value) {
  final match =
      RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch('${value ?? ''}');
  return match == null
      ? null
      : int.parse(match[1]!) * 60 + int.parse(match[2]!);
}

double _round(double value, int digits) =>
    double.parse(value.toStringAsFixed(digits));

/// `numerator / denominator` rounded half up at [places] decimals with integer
/// arithmetic, like the server's exact-decimal `round_half_up` (a binary double
/// would round some 0.xxx5 values down).
double _halfUp(int numerator, int denominator, int places) {
  var scale = 1;
  for (var i = 0; i < places; i++) {
    scale *= 10;
  }
  final scaled = numerator * scale;
  return ((2 * scaled + denominator) ~/ (2 * denominator)) / scale;
}

/// A local `preview_leave_request` for the offline preview: the server's rules
/// except holidays, where only Friday is a day off. Errors are data, as on the
/// server. [args]: `leave_type`, `request_kind` (`Daily` / `Hourly`),
/// `start_date`, `end_date`, `leave_date`, `start_time`, `end_time`.
Map<String, dynamic> offlinePreviewLeave(Map<String, dynamic> args) {
  final balance = offlineLeaveBalance();
  final dailyHours = (balance['daily_working_hours'] as num).toDouble();
  final errors = <Map<String, dynamic>>[];
  void error(String code, String field, [String? message]) => errors.add({
        'code': code,
        'field': field,
        'message': message ?? _leaveErrorMessages[code] ?? code
      });

  Map<String, dynamic>? duration;
  var holidays = 0;
  if ('${args['request_kind']}' == 'Hourly') {
    final date = DateTime.tryParse('${args['leave_date'] ?? ''}');
    final start = _minutes(args['start_time']);
    final end = _minutes(args['end_time']);
    if (date != null && start != null && end != null) {
      final minutes = end - start;
      final limit = (dailyHours * 60).round();
      if (minutes <= 0) {
        error('INVALID_TIME_RANGE', 'end_time');
      } else if (minutes < 15) {
        // Like the server, a broken time rule gives no duration.
        error('INVALID_TIME_RANGE', 'end_time',
            'حداقل مدت مرخصی ساعتی ۱۵ دقیقه است.');
      } else if (minutes > limit) {
        error('HOURLY_EXCEEDS_DAY', 'end_time');
      } else {
        // hours: minutes / 60 at 2 decimals; day_equivalent: that figure over
        // the daily hours at 4 decimals (CONTRACT §3.6).
        final hours = _halfUp(minutes, 60, 2);
        duration = {
          'unit': 'hour',
          'days': null,
          'hours': hours,
          'day_equivalent':
              _halfUp((hours * 100).round(), (dailyHours * 100).round(), 4),
        };
      }
      if (date.weekday == DateTime.friday) {
        error('HOURLY_ON_HOLIDAY', 'leave_date');
      }
    }
  } else {
    final from = DateTime.tryParse('${args['start_date'] ?? ''}');
    final to = DateTime.tryParse('${args['end_date'] ?? ''}');
    if (from != null && to != null) {
      if (to.isBefore(from)) {
        error('INVALID_DATE_RANGE', 'end_date');
      } else {
        var days = 0;
        for (var day = DateTime(from.year, from.month, from.day);
            !day.isAfter(to);
            day = DateTime(day.year, day.month, day.day + 1)) {
          day.weekday == DateTime.friday ? holidays++ : days++;
        }
        if (days <= 0) {
          error('LEAVE_ALL_HOLIDAYS', 'start_date');
        } else {
          duration = {
            'unit': 'day',
            'days': days.toDouble(),
            'hours': null,
            'day_equivalent': days.toDouble(),
          };
        }
      }
    }
  }

  Map<String, dynamic>? result;
  final type = _sampleOptions['Leave Type']!
      .where((row) => row['value'] == args['leave_type'])
      .firstOrNull;
  if (duration != null && type != null) {
    final requested = (duration['day_equivalent'] as num).toDouble();
    final row = (balance['leave_types'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((row) => row['leave_type'] == type['value']);
    final remaining = (row['remaining'] as num?)?.toDouble();
    final available = (row['available'] as num?)?.toDouble();
    if (remaining != null && available != null && type['is_lwp'] != 1) {
      // The server compares with `available` (remaining minus pending).
      if (requested > available) {
        error('INSUFFICIENT_LEAVE_BALANCE', 'leave_type');
      }
      result = {
        'leave_type': type['value'],
        'remaining_before': remaining,
        'requested_days': requested,
        'remaining_after': _round(remaining - requested, 3),
        'available_after': _round(available - requested, 3),
      };
    }
  }
  return {
    'valid': errors.isEmpty && duration != null,
    'errors': errors,
    'duration': duration ??
        {'unit': '', 'days': null, 'hours': null, 'day_equivalent': null},
    'balance': result,
    'holidays_excluded': holidays,
  };
}
