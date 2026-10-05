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

/// Where [PreviewFallbackWorkflowRepository] keeps the locally designed workflows.
const previewDesignsKey = 'asoud_workflow_designs_v2';

/// A sample request type so the request flow can be tried before any design.
/// Never transferred: `is_sample` rows are seed data, not user data.
const offlineSampleRequestType = <String, dynamic>{
  'name': 'PREVIEW-REQUEST-PURCHASE',
  'is_sample': true,
  'workflow_title': 'درخواست خرید (نمونه آفلاین)',
  'short_title': 'ثبت درخواست خرید کالا و خدمات',
  'icon_key': 'purchase',
  'request_category': 'Purchase',
  'fields': [
    {
      'key': 'category',
      'label': 'دسته‌بندی',
      'type': 'Choice',
      'required': true,
      'options': ['تجهیزات IT', 'ملزومات اداری', 'خدمات'],
    },
    {'key': 'description', 'label': 'شرح درخواست', 'type': 'Long Text'},
    {'key': 'total', 'label': 'مبلغ کل درخواست', 'type': 'Currency'},
    {'key': 'items', 'label': 'اقلام درخواستی', 'type': 'Item Table'},
  ],
};

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

/// Request types available offline: locally designed ones, then the demo
/// types («شرکت نمونه آسود», each `is_sample: true`) when nothing was
/// designed yet, then the sample.
Future<List<Map<String, dynamic>>> offlineRequestTypes() async {
  final designs = await _designs();
  final all = [...designs, if (designs.isEmpty) ...demoDesignMaps()];
  return [
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
    offlineSampleRequestType,
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
    {'value': 'PREVIEW-LAPTOP', 'label': 'لپ‌تاپ', 'stock_uom': 'عدد'},
    {'value': 'PREVIEW-MOUSE', 'label': 'ماوس بی‌سیم', 'stock_uom': 'عدد'},
    {'value': 'PREVIEW-PAPER', 'label': 'کاغذ A4', 'stock_uom': 'بسته'},
  ],
  'User': [
    {'value': 'preview.manager@local', 'label': 'مدیر نمونه'},
    {'value': 'preview.user@local', 'label': 'کارشناس نمونه'},
  ],
  'Department': [
    {'value': 'PREVIEW-FINANCE', 'label': 'مالی و حسابداری'},
    {'value': 'PREVIEW-TRADE', 'label': 'بازرگانی'},
    {'value': 'PREVIEW-IT', 'label': 'فناوری اطلاعات'},
  ],
};

/// Sample choices for User, Department, Item and UOM fields while offline.
List<Map<String, dynamic>> offlineFieldOptions(String fieldType,
    {String txt = '', String? itemCode}) {
  if (fieldType == 'UOM') {
    final item = _sampleOptions['Item']!
        .where((row) => row['value'] == itemCode)
        .firstOrNull;
    final uom = '${item?['stock_uom'] ?? 'عدد'}';
    return [
      {'value': uom, 'label': uom, 'conversion_factor': 1}
    ];
  }
  return [
    for (final row
        in _sampleOptions[fieldType] ?? const <Map<String, dynamic>>[])
      if (txt.isEmpty || '${row['label']}'.contains(txt)) row
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
