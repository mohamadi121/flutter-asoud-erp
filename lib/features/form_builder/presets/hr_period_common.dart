import '../form_repository.dart';

/// «مشخصات متقاضی»: the signed-in person, filled by `default_source`, read-only.
FormMap hrApplicantSection() => {
      'id': 'applicant_details',
      'title': 'مشخصات متقاضی',
      'icon': 'person',
      'color': '#E8F2FF',
      'fields': <FormMap>[
        {
          'key': 'applicant_employee',
          'label': 'نام و نام خانوادگی',
          'type': 'Link',
          'source': 'Employee',
          'default_source': 'employee',
          'readonly': true,
          'required': true,
          'span': 2,
        },
        {
          'key': 'applicant_department',
          'label': 'واحد سازمانی',
          'type': 'Link',
          'source': 'Department',
          'default_source': 'department',
          'readonly': true,
          'span': 1,
        },
        {
          'key': 'applicant_position',
          'label': 'سمت سازمانی',
          'type': 'Text',
          'default_source': 'designation',
          'readonly': true,
          'span': 1,
        },
      ],
    };

/// «گردش تأیید»: the routing lives in the workflow designer, never in the form.
FormMap hrApprovalFlowSection() => {
      'id': 'approval_flow',
      'title': 'گردش تأیید',
      'icon': 'account_tree',
      'color': '#FCE9EE',
      'fields': <FormMap>[
        {
          'key': 'approval_flow_notice',
          'label': 'مسیر بررسی',
          'type': 'Display',
          'span': 2,
          'default': 'مسیر بررسی از گردش کار تعریف‌شده تعیین می‌شود.',
        },
      ],
    };

const hrRangeOrderMessage = 'تاریخ پایان نباید پیش از تاریخ شروع باشد.';
const hrHalfDayRangeMessage = 'تاریخ نیم‌روز باید در بازه درخواست باشد.';

/// Start, end and an optional half day inside the range (daily or half-day only).
List<FormMap> hrDateRangeFields() => <FormMap>[
      {
        'key': 'from_date',
        'label': 'تاریخ شروع',
        'type': 'Date',
        'default_source': 'today',
        'required': true,
        'span': 1,
      },
      {
        'key': 'to_date',
        'label': 'تاریخ پایان',
        'type': 'Date',
        'required': true,
        'after_or_equal': 'from_date',
        'after_or_equal_message': hrRangeOrderMessage,
        'span': 1,
      },
      {
        'key': 'half_day',
        'label': 'نیم‌روز',
        'type': 'Boolean',
        'default': false,
        'span': 2,
      },
      {
        'key': 'half_day_date',
        'label': 'تاریخ نیم‌روز',
        'type': 'Date',
        'after_or_equal': 'from_date',
        'after_or_equal_message': hrHalfDayRangeMessage,
        'before_or_equal': 'to_date',
        'before_or_equal_message': hrHalfDayRangeMessage,
        'span': 2,
      },
    ];

/// The half-day date appears, and is required, only when «نیم‌روز» is on.
List<FormMap> hrHalfDayRules() => <FormMap>[
      for (final action in ['visible', 'required'])
        {
          'target': 'half_day_date',
          'action': action,
          'join': 'and',
          'conditions': <FormMap>[
            {'field': 'half_day', 'op': 'eq', 'value': true},
          ],
        },
    ];
