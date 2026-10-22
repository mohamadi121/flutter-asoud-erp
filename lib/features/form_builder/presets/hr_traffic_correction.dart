import '../form_repository.dart';

/// فرم خامِ درخواست اصلاح تردد؛ مسیر تأیید و اعمال اصلاح به گردش کار سپرده می‌شود.
FormMap hrTrafficCorrectionPreset() => {
      'schema_version': 2,
      'format': 1,
      'kind': 'Request',
      'title': 'درخواست اصلاح تردد',
      'module': 'HR',
      'icon': 'clock',
      'color': '#6B5CE7',
      'description': 'فرم درخواست اصلاح ورود، خروج یا ساعت ثبت‌شده تردد',
      'sections': [
        {
          'id': 'applicant',
          'title': 'مشخصات متقاضی',
          'icon': 'person',
          'color': '#E8F2FF',
          'fields': [
            {
              'key': 'applicant_name',
              'label': 'نام و نام خانوادگی',
              'type': 'Display',
              'readonly': true,
              'default': 'دریافت خودکار',
            },
            {
              'key': 'applicant_department',
              'label': 'واحد سازمانی',
              'type': 'Display',
              'readonly': true,
              'default': 'دریافت خودکار',
              'span': 1,
            },
            {
              'key': 'applicant_position',
              'label': 'سمت سازمانی',
              'type': 'Display',
              'readonly': true,
              'default': 'دریافت خودکار',
              'span': 1,
            },
          ],
        },
        {
          'id': 'traffic_details',
          'title': 'مشخصات اصلاح تردد',
          'icon': 'schedule',
          'color': '#F2EAFE',
          'fields': [
            {
              'key': 'correction_type',
              'label': 'نوع اصلاح',
              'type': 'Select',
              'required': true,
              'options': [
                {'id': 'missing_check_in', 'label': 'فراموشی ثبت ورود'},
                {'id': 'missing_check_out', 'label': 'فراموشی ثبت خروج'},
                {'id': 'correct_recorded_time', 'label': 'اصلاح ساعت ثبت‌شده'},
                {'id': 'other', 'label': 'سایر موارد'},
              ],
            },
            {
              'key': 'attendance_date',
              'label': 'تاریخ تردد',
              'type': 'Date',
              'required': true,
            },
            {
              'key': 'proposed_check_in_time',
              'label': 'ساعت ورود پیشنهادی',
              'type': 'Time',
            },
            {
              'key': 'proposed_check_out_time',
              'label': 'ساعت خروج پیشنهادی',
              'type': 'Time',
            },
            {
              'key': 'attendance_record',
              'label': 'رکورد تردد',
              'type': 'Link',
              'source': 'Attendance',
            },
            {
              'key': 'current_recorded_time',
              'label': 'ساعت ثبت‌شده فعلی',
              'type': 'Display',
              'readonly': true,
            },
            {
              'key': 'proposed_correct_time',
              'label': 'ساعت صحیح پیشنهادی',
              'type': 'Time',
            },
            {
              'key': 'other_correction_description',
              'label': 'شرح نوع اصلاح',
              'type': 'LongText',
              'help': 'توضیح دهید چه موردی باید اصلاح شود.',
            },
          ],
        },
        {
          'id': 'reason',
          'title': 'علت درخواست',
          'icon': 'edit_note',
          'color': '#FFF0DD',
          'fields': [
            {
              'key': 'correction_reason',
              'label': 'دلیل اصلاح تردد',
              'type': 'LongText',
              'required': true,
              'help': 'علت ثبت‌نشدن یا اشتباه‌بودن تردد را توضیح دهید.',
            },
          ],
        },
        {
          'id': 'attachments',
          'title': 'پیوست‌ها',
          'icon': 'attach_file',
          'color': '#E6F6F7',
          'fields': [
            {'key': 'attachments', 'label': 'پیوست‌ها', 'type': 'File'},
          ],
        },
        {
          'id': 'approval_flow',
          'title': 'گردش تأیید',
          'icon': 'account_tree',
          'color': '#FCE9EE',
          'fields': <FormMap>[],
        },
        {
          'id': 'review_submit',
          'title': 'بررسی نهایی و ارسال',
          'icon': 'fact_check',
          'color': '#E5F7EF',
          'fields': <FormMap>[],
        },
      ],
      'rules': [
        {
          'target': 'proposed_check_in_time',
          'action': 'visible',
          'join': 'and',
          'conditions': [
            {'field': 'correction_type', 'op': 'eq', 'value': 'missing_check_in'},
          ],
        },
        {
          'target': 'proposed_check_in_time',
          'action': 'required',
          'join': 'and',
          'conditions': [
            {'field': 'correction_type', 'op': 'eq', 'value': 'missing_check_in'},
          ],
        },
        {
          'target': 'proposed_check_out_time',
          'action': 'visible',
          'join': 'and',
          'conditions': [
            {'field': 'correction_type', 'op': 'eq', 'value': 'missing_check_out'},
          ],
        },
        {
          'target': 'proposed_check_out_time',
          'action': 'required',
          'join': 'and',
          'conditions': [
            {'field': 'correction_type', 'op': 'eq', 'value': 'missing_check_out'},
          ],
        },
        {
          'target': 'attendance_record',
          'action': 'visible',
          'join': 'and',
          'conditions': [
            {'field': 'correction_type', 'op': 'eq', 'value': 'correct_recorded_time'},
          ],
        },
        {
          'target': 'attendance_record',
          'action': 'required',
          'join': 'and',
          'conditions': [
            {'field': 'correction_type', 'op': 'eq', 'value': 'correct_recorded_time'},
          ],
        },
        {
          'target': 'current_recorded_time',
          'action': 'visible',
          'join': 'and',
          'conditions': [
            {'field': 'correction_type', 'op': 'eq', 'value': 'correct_recorded_time'},
          ],
        },
        {
          'target': 'proposed_correct_time',
          'action': 'visible',
          'join': 'and',
          'conditions': [
            {'field': 'correction_type', 'op': 'eq', 'value': 'correct_recorded_time'},
          ],
        },
        {
          'target': 'proposed_correct_time',
          'action': 'required',
          'join': 'and',
          'conditions': [
            {'field': 'correction_type', 'op': 'eq', 'value': 'correct_recorded_time'},
          ],
        },
        {
          'target': 'other_correction_description',
          'action': 'visible',
          'join': 'and',
          'conditions': [
            {'field': 'correction_type', 'op': 'eq', 'value': 'other'},
          ],
        },
        {
          'target': 'other_correction_description',
          'action': 'required',
          'join': 'and',
          'conditions': [
            {'field': 'correction_type', 'op': 'eq', 'value': 'other'},
          ],
        },
      ],
      'access': {'mode': 'all', 'roles': [], 'departments': []},
    };
