import '../form_repository.dart';

/// Raw reusable request schema; workflow routing and shift execution stay external.
FormMap hrShiftChangePreset() => {
      'schema_version': 2,
      'kind': 'Request',
      'title': 'درخواست تغییر شیفت',
      'module': 'HR',
      'icon': 'calendar',
      'color': '#1876D2',
      'description': 'قالب خام درخواست تغییر شیفت یا جابه‌جایی شیفت با همکار',
      'sections': <FormMap>[
        {
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
        },
        {
          'id': 'shift_details',
          'title': 'مشخصات تغییر شیفت',
          'icon': 'schedule',
          'color': '#F2EAFE',
          'fields': <FormMap>[
            {
              'key': 'change_type',
              'label': 'نوع تغییر',
              'type': 'Select',
              'default': 'self_change',
              'required': true,
              'style': 'radio',
              'options': <FormMap>[
                {'id': 'self_change', 'label': 'تغییر شیفت خودم'},
                {'id': 'swap_with_colleague', 'label': 'جابه‌جایی شیفت با همکار'},
              ],
            },
            {
              'key': 'duration_mode',
              'label': 'مدت درخواست',
              'type': 'Select',
              'default': 'single_day',
              'required': true,
              'style': 'radio',
              'options': <FormMap>[
                {'id': 'single_day', 'label': 'یک روز'},
                {'id': 'date_range', 'label': 'بازه زمانی'},
              ],
            },
            {
              'key': 'change_date',
              'label': 'تاریخ تغییر',
              'type': 'Date',
              'required': true,
              'span': 2,
            },
            {
              'key': 'start_date',
              'label': 'تاریخ شروع',
              'type': 'Date',
              'span': 1,
            },
            {
              'key': 'end_date',
              'label': 'تاریخ پایان',
              'type': 'Date',
              'after_or_equal': 'start_date',
              'after_or_equal_message': 'تاریخ پایان نباید قبل از تاریخ شروع باشد.',
              'span': 1,
            },
            {
              'key': 'current_shift',
              'label': 'شیفت فعلی',
              'type': 'Display',
              'default': 'برنامه شیفت برای این تاریخ در دسترس نیست.',
              'readonly': true,
              'span': 2,
            },
            {
              'key': 'requested_shift',
              'label': 'شیفت جایگزین درخواستی',
              'type': 'Text',
              'required': true,
              'span': 2,
              'help': 'نام یا شناسه شیفت درخواستی را وارد کنید؛ اعتبارسنجی و اعمال تغییر به اتصال برنامه‌ریزی شیفت نیاز دارد.',
            },
            {
              'key': 'exchange_colleague',
              'label': 'همکار طرف جابه‌جایی',
              'type': 'Link',
              'source': 'Employee',
              'span': 2,
            },
            {
              'key': 'colleague_schedule_note',
              'label': 'برنامه همکار',
              'type': 'Display',
              'default': 'برنامه همکار پس از انتخاب از منبع معتبر بررسی می‌شود.',
              'readonly': true,
              'span': 2,
            },
          ],
        },
        {
          'id': 'reason_details',
          'title': 'دلیل درخواست',
          'icon': 'notes',
          'color': '#FFF0DD',
          'fields': <FormMap>[
            {
              'key': 'reason',
              'label': 'علت تغییر شیفت',
              'type': 'Select',
              'required': true,
              'options': <FormMap>[
                {'id': 'personal', 'label': 'امور شخصی'},
                {'id': 'medical', 'label': 'دلایل درمانی'},
                {'id': 'family', 'label': 'مسائل خانوادگی'},
                {'id': 'other', 'label': 'سایر موارد'},
              ],
            },
            {
              'key': 'reason_description',
              'label': 'شرح علت',
              'type': 'LongText',
              'span': 2,
            },
            {
              'key': 'additional_notes',
              'label': 'توضیحات تکمیلی',
              'type': 'LongText',
              'span': 2,
            },
          ],
        },
      ],
      'rules': <FormMap>[
        {
          'target': 'change_date',
          'action': 'visible',
          'join': 'and',
          'conditions': <FormMap>[
            {'field': 'duration_mode', 'op': 'eq', 'value': 'single_day'},
          ],
        },
        {
          'target': 'start_date',
          'action': 'visible',
          'join': 'and',
          'conditions': <FormMap>[
            {'field': 'duration_mode', 'op': 'eq', 'value': 'date_range'},
          ],
        },
        {
          'target': 'start_date',
          'action': 'required',
          'join': 'and',
          'conditions': <FormMap>[
            {'field': 'duration_mode', 'op': 'eq', 'value': 'date_range'},
          ],
        },
        {
          'target': 'end_date',
          'action': 'visible',
          'join': 'and',
          'conditions': <FormMap>[
            {'field': 'duration_mode', 'op': 'eq', 'value': 'date_range'},
          ],
        },
        {
          'target': 'end_date',
          'action': 'required',
          'join': 'and',
          'conditions': <FormMap>[
            {'field': 'duration_mode', 'op': 'eq', 'value': 'date_range'},
          ],
        },
        {
          'target': 'exchange_colleague',
          'action': 'visible',
          'join': 'and',
          'conditions': <FormMap>[
            {'field': 'change_type', 'op': 'eq', 'value': 'swap_with_colleague'},
          ],
        },
        {
          'target': 'exchange_colleague',
          'action': 'required',
          'join': 'and',
          'conditions': <FormMap>[
            {'field': 'change_type', 'op': 'eq', 'value': 'swap_with_colleague'},
          ],
        },
        {
          'target': 'colleague_schedule_note',
          'action': 'visible',
          'join': 'and',
          'conditions': <FormMap>[
            {'field': 'change_type', 'op': 'eq', 'value': 'swap_with_colleague'},
          ],
        },
        {
          'target': 'reason_description',
          'action': 'visible',
          'join': 'and',
          'conditions': <FormMap>[
            {'field': 'reason', 'op': 'eq', 'value': 'other'},
          ],
        },
        {
          'target': 'reason_description',
          'action': 'required',
          'join': 'and',
          'conditions': <FormMap>[
            {'field': 'reason', 'op': 'eq', 'value': 'other'},
          ],
        },
      ],
    };
