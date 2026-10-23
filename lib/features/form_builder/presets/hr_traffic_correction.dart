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
              'key': 'applicant_employee',
              'label': 'نام و نام خانوادگی',
              'type': 'Link',
              'source': 'Employee',
              'default_source': 'employee',
              'readonly': true,
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
              'help': 'ساعت ورود را از ساعت‌گزین انتخاب کنید.',
            },
            {
              'key': 'proposed_check_out_time',
              'label': 'ساعت خروج پیشنهادی',
              'type': 'Time',
              'help': 'ساعت خروج را از ساعت‌گزین انتخاب کنید.',
            },
            {
              'key': 'attendance_record',
              'label': 'رکورد تردد',
              'type': 'Link',
              'source': 'Attendance',
              'link_filter': {'field': 'attendance_date', 'value_field': 'attendance_date'},
              'help': 'پس از انتخاب تاریخ تردد، رکورد ثبت‌شده همان روز را انتخاب کنید.',
            },
            {
              'key': 'recorded_event',
              'label': 'کدام ساعت اصلاح شود؟',
              'type': 'Select',
              'style': 'radio',
              'options': [
                {'id': 'check_in', 'label': 'ساعت ورود'},
                {'id': 'check_out', 'label': 'ساعت خروج'},
              ],
            },
            {
              'key': 'current_in_time',
              'label': 'ساعت ورود ثبت‌شده فعلی',
              'type': 'Time',
              'readonly': true,
              'fetch_from': 'attendance_record.in_time',
            },
            {
              'key': 'proposed_correct_in_time',
              'label': 'ساعت ورود صحیح پیشنهادی',
              'type': 'Time',
              'not_equal': 'current_in_time',
              'not_equal_message': 'ساعت پیشنهادی با ساعت ثبت‌شده فعلی یکسان است.',
              'help': 'ساعت صحیح را از ساعت‌گزین انتخاب کنید.',
            },
            {
              'key': 'current_out_time',
              'label': 'ساعت خروج ثبت‌شده فعلی',
              'type': 'Time',
              'readonly': true,
              'fetch_from': 'attendance_record.out_time',
            },
            {
              'key': 'proposed_correct_out_time',
              'label': 'ساعت خروج صحیح پیشنهادی',
              'type': 'Time',
              'not_equal': 'current_out_time',
              'not_equal_message': 'ساعت پیشنهادی با ساعت ثبت‌شده فعلی یکسان است.',
              'help': 'ساعت صحیح را از ساعت‌گزین انتخاب کنید.',
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
          'fields': [
            {
              'key': 'approval_flow_notice',
              'label': 'مسیر بررسی',
              'type': 'Display',
              'default': 'مسیر بررسی از گردش کار تعریف‌شده تعیین می‌شود.',
            },
          ],
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
          'target': 'recorded_event',
          'action': 'visible',
          'join': 'and',
          'conditions': [
            {'field': 'correction_type', 'op': 'eq', 'value': 'correct_recorded_time'},
          ],
        },
        {
          'target': 'recorded_event',
          'action': 'required',
          'join': 'and',
          'conditions': [
            {'field': 'correction_type', 'op': 'eq', 'value': 'correct_recorded_time'},
          ],
        },
        {
          'target': 'current_in_time',
          'action': 'visible',
          'join': 'and',
          'conditions': [
            {'field': 'correction_type', 'op': 'eq', 'value': 'correct_recorded_time'},
            {'field': 'recorded_event', 'op': 'eq', 'value': 'check_in'},
          ],
        },
        {
          'target': 'proposed_correct_in_time',
          'action': 'visible',
          'join': 'and',
          'conditions': [
            {'field': 'correction_type', 'op': 'eq', 'value': 'correct_recorded_time'},
            {'field': 'recorded_event', 'op': 'eq', 'value': 'check_in'},
          ],
        },
        {
          'target': 'proposed_correct_in_time',
          'action': 'required',
          'join': 'and',
          'conditions': [
            {'field': 'correction_type', 'op': 'eq', 'value': 'correct_recorded_time'},
            {'field': 'recorded_event', 'op': 'eq', 'value': 'check_in'},
          ],
        },
        {
          'target': 'current_out_time',
          'action': 'visible',
          'join': 'and',
          'conditions': [
            {'field': 'correction_type', 'op': 'eq', 'value': 'correct_recorded_time'},
            {'field': 'recorded_event', 'op': 'eq', 'value': 'check_out'},
          ],
        },
        {
          'target': 'proposed_correct_out_time',
          'action': 'visible',
          'join': 'and',
          'conditions': [
            {'field': 'correction_type', 'op': 'eq', 'value': 'correct_recorded_time'},
            {'field': 'recorded_event', 'op': 'eq', 'value': 'check_out'},
          ],
        },
        {
          'target': 'proposed_correct_out_time',
          'action': 'required',
          'join': 'and',
          'conditions': [
            {'field': 'correction_type', 'op': 'eq', 'value': 'correct_recorded_time'},
            {'field': 'recorded_event', 'op': 'eq', 'value': 'check_out'},
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
    };
