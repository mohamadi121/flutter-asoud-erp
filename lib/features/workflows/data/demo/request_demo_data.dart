/// Demo rows for the offline preview (no session): the mission and advance
/// request types backed by local designs, four requests across the statuses
/// and the cartable timeline behind them. The leave and purchase demos live
/// with the system templates (`RequestDemoRegistry`).
///
/// Every map carries `is_sample: true` and is served only in preview; an
/// authenticated session never sees these rows.
library;

import '../../../office_setup/data/demo/office_demo_data.dart';

String _iso(DateTime value) => value.toIso8601String();

Map<String, dynamic> _design({
  required String id,
  required String title,
  required String shortTitle,
  required String iconKey,
  required String category,
  required List<Map<String, dynamic>> fields,
}) =>
    {
      'is_sample': true,
      'workflow': {
        'id': id,
        'title': title,
        'target_doctype': 'ASOUD Workflow Request',
        'company': demoCompanyName,
        'short_title': shortTitle,
        'icon_key': iconKey,
        'category': category,
        'show_in_list': true,
        'user_submittable': true,
      },
      'stages': [
        {
          'id': '$id-START',
          'key': 'START',
          'type': 'start',
          'title': 'شروع',
          'sequence': 1,
          'complete': true,
          'config': {'trigger_type': 'Manual'},
        },
        {
          'id': '$id-FORM',
          'key': 'FORM',
          'type': 'userTask',
          'title': 'فرم درخواست',
          'sequence': 2,
          'complete': true,
          'config': {'form_fields': fields},
        },
      ],
      'transitions': [
        {'id': '$id-T1', 'from': '$id-START', 'to': '$id-FORM'},
      ],
    };

/// Local designs behind the demo request types.
List<Map<String, dynamic>> demoDesignMaps() => [
      _design(
        id: 'DEMO-WF-MISSION',
        title: 'درخواست مأموریت',
        shortTitle: 'ثبت درخواست مأموریت کاری',
        iconKey: 'mission',
        category: 'HR',
        fields: [
          {
            'key': 'destination',
            'label': 'مقصد',
            'type': 'Text',
            'required': true
          },
          {
            'key': 'from_date',
            'label': 'از تاریخ',
            'type': 'Date',
            'required': true
          },
          {
            'key': 'to_date',
            'label': 'تا تاریخ',
            'type': 'Date',
            'required': true
          },
          {'key': 'purpose', 'label': 'هدف مأموریت', 'type': 'Long Text'},
          {'key': 'advance', 'label': 'پیش‌پرداخت مأموریت', 'type': 'Currency'},
        ],
      ),
      _design(
        id: 'DEMO-WF-ADVANCE',
        title: 'درخواست تنخواه',
        shortTitle: 'ثبت درخواست تنخواه گردان',
        iconKey: 'advance',
        category: 'Finance',
        fields: [
          {
            'key': 'amount',
            'label': 'مبلغ تنخواه',
            'type': 'Currency',
            'required': true
          },
          {'key': 'purpose', 'label': 'مورد مصرف', 'type': 'Long Text'},
          {'key': 'needed_by', 'label': 'تاریخ نیاز', 'type': 'Date'},
          {
            'key': 'repayment',
            'label': 'نحوه تسویه',
            'type': 'Choice',
            'options': ['کسر از حقوق', 'بازپرداخت نقدی'],
          },
        ],
      ),
    ];

Map<String, dynamic> _request({
  required String name,
  required String type,
  required String typeTitle,
  required String subject,
  required String status,
  required int daysAgo,
  required Map<String, dynamic> values,
  String? displayStatus,
  String? instance,
  List<Map<String, dynamic>> attachments = const [],
  String requester = 'سارا محمدی',
  String department = 'فروش',
}) {
  final created = DateTime.now().subtract(Duration(days: daysAgo));
  return {
    'is_sample': true,
    'name': name,
    'company': demoCompanyName,
    'workflow_definition': type,
    'request_type': typeTitle,
    'subject': subject,
    'status': status,
    if (displayStatus != null) 'display_status': displayStatus,
    'creation': _iso(created),
    'requester_name': requester,
    'requester': requester,
    'department': department,
    'values': values,
    'attachments': attachments,
    if (instance != null) 'workflow_instance': instance,
  };
}

/// Four demo requests (mission and advance): waiting, approved and rejected —
/// dates relative to now.
List<Map<String, dynamic>> demoRequests() {
  final now = DateTime.now();
  String iso(int daysAgo, [int hours = 0]) =>
      _iso(now.subtract(Duration(days: daysAgo, hours: hours)));
  return [
    _request(
      name: 'DEMO-REQ-003',
      type: 'DEMO-WF-MISSION',
      typeTitle: 'درخواست مأموریت',
      subject: 'مأموریت تهران — نمایشگاه',
      status: 'Completed',
      daysAgo: 9,
      instance: 'DEMO-WFI-003',
      values: {
        'destination': 'تهران',
        'from_date': iso(9).substring(0, 10),
        'to_date': iso(7).substring(0, 10),
        'purpose': 'حضور در نمایشگاه و دیدار با مشتریان',
        'advance': 20000000,
      },
      attachments: [
        {
          'name': 'DEMO-FILE-1',
          'filename': 'دعوت‌نامه نمایشگاه.pdf',
          'is_sample': true
        },
      ],
    ),
    _request(
      name: 'DEMO-REQ-004',
      type: 'DEMO-WF-ADVANCE',
      typeTitle: 'درخواست تنخواه',
      subject: 'تنخواه خرداد واحد فروش',
      status: 'Rejected',
      daysAgo: 12,
      instance: 'DEMO-WFI-004',
      values: {
        'amount': 50000000,
        'purpose': 'هزینه‌های پذیرایی و ایاب و ذهاب خرداد',
        'needed_by': iso(12).substring(0, 10),
        'repayment': 'کسر از حقوق',
      },
    ),
    _request(
      name: 'DEMO-REQ-007',
      type: 'DEMO-WF-MISSION',
      typeTitle: 'درخواست مأموریت',
      subject: 'مأموریت اصفهان — بازدید مشتری',
      status: 'Running',
      daysAgo: 0,
      instance: 'DEMO-WFI-007',
      values: {
        'destination': 'اصفهان',
        'from_date': iso(-2).substring(0, 10),
        'to_date': iso(-1).substring(0, 10),
        'purpose': 'بازدید از خط تولید مشتری و عقد قرارداد پشتیبانی',
        'advance': 15000000,
      },
    ),
    _request(
      name: 'DEMO-REQ-008',
      type: 'DEMO-WF-ADVANCE',
      typeTitle: 'درخواست تنخواه',
      subject: 'تنخواه تیر پروژه نمونه',
      status: 'Completed',
      daysAgo: 20,
      instance: 'DEMO-WFI-008',
      values: {
        'amount': 30000000,
        'purpose': 'خرید مصالح جزئی پروژه نمونه',
        'needed_by': iso(20).substring(0, 10),
        'repayment': 'بازپرداخت نقدی',
      },
    ),
  ];
}

Map<String, dynamic> _activity({
  required String actor,
  required String action,
  required int daysAgo,
  String comment = '',
  String stage = '',
  int hours = 0,
}) =>
    {
      'actor': actor,
      'action': action,
      'comment': comment,
      'stage_title': stage,
      'created_on':
          _iso(DateTime.now().subtract(Duration(days: daysAgo, hours: hours))),
    };

/// Cartable timeline (activities + comments) behind each demo request.
List<Map<String, dynamic>> demoInstanceTimeline(String instance) {
  switch (instance) {
    case 'DEMO-WFI-002':
      return [
        _activity(
            actor: 'سارا محمدی',
            action: 'Create',
            stage: 'ثبت درخواست',
            daysAgo: 2,
            comment: 'درخواست خرید دو لپ‌تاپ ثبت شد.'),
        _activity(
            actor: 'موتور گردش‌کار',
            action: 'Assign',
            stage: 'ارجاع به مدیر مستقیم',
            daysAgo: 2,
            hours: 3),
        _activity(
            actor: 'احمد رضایی',
            action: 'Comment',
            stage: 'بررسی مدیر',
            daysAgo: 1,
            comment: 'لطفاً پیش‌فاکتور را پیوست کنید.'),
      ];
    case 'DEMO-WFI-003':
      return [
        _activity(
            actor: 'سارا محمدی',
            action: 'Create',
            stage: 'ثبت درخواست',
            daysAgo: 9),
        _activity(
            actor: 'احمد رضایی',
            action: 'Approve',
            stage: 'تأیید مدیر مستقیم',
            daysAgo: 8,
            comment: 'با مأموریت موافقت شد.'),
        _activity(
            actor: 'مدیر مالی',
            action: 'Approve',
            stage: 'تأیید مالی',
            daysAgo: 8,
            hours: 5,
            comment: 'پیش‌پرداخت واریز شد.'),
        _activity(
            actor: 'موتور گردش‌کار',
            action: 'Complete',
            stage: 'پایان فرایند',
            daysAgo: 7),
      ];
    case 'DEMO-WFI-004':
      return [
        _activity(
            actor: 'سارا محمدی',
            action: 'Create',
            stage: 'ثبت درخواست',
            daysAgo: 12),
        _activity(
            actor: 'احمد رضایی',
            action: 'Reject',
            stage: 'بررسی مدیر',
            daysAgo: 11,
            comment: 'سقف تنخواه خرداد تکمیل است؛ در تیر ثبت کنید.'),
      ];
    case 'DEMO-WFI-005':
      return [
        _activity(
            actor: 'سارا محمدی',
            action: 'Create',
            stage: 'ثبت درخواست',
            daysAgo: 1,
            hours: 6),
        _activity(
            actor: 'احمد رضایی',
            action: 'Return',
            stage: 'بررسی مدیر',
            daysAgo: 1,
            comment: 'مبلغ هر قلم را جدا بنویسید و دوباره ارسال کنید.'),
      ];
    case 'DEMO-WFI-007':
      return [
        _activity(
            actor: 'سارا محمدی',
            action: 'Create',
            stage: 'ثبت درخواست',
            daysAgo: 0,
            hours: 4,
            comment: 'بازدید پنجشنبه انجام می‌شود.'),
      ];
    case 'DEMO-WFI-008':
      return [
        _activity(
            actor: 'سارا محمدی',
            action: 'Create',
            stage: 'ثبت درخواست',
            daysAgo: 20),
        _activity(
            actor: 'احمد رضایی',
            action: 'Approve',
            stage: 'تأیید مدیر مستقیم',
            daysAgo: 19,
            comment: 'مورد تأیید است.'),
        _activity(
            actor: 'موتور گردش‌کار',
            action: 'Complete',
            stage: 'پایان فرایند',
            daysAgo: 18),
      ];
    default:
      return const [];
  }
}
