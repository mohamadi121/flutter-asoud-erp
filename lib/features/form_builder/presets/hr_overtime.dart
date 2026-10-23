import '../form_repository.dart';
import 'hr_period_common.dart';

const hrOvertimeOrderMessage = 'ساعت پایان باید پس از ساعت شروع باشد.';

/// Raw reusable overtime request; approval ends as an HR action, not a document.
FormMap hrOvertimePreset() => {
      'schema_version': 2,
      'kind': 'Request',
      'title': 'درخواست اضافه‌کار',
      'module': 'HR',
      'icon': 'clock',
      'color': '#6B5CE7',
      'description': 'قالب خام درخواست اضافه‌کار یک روز با ساعت شروع و پایان',
      'sections': <FormMap>[
        hrApplicantSection(),
        {
          'id': 'overtime_details',
          'title': 'مشخصات اضافه‌کار',
          'icon': 'schedule',
          'color': '#F2EAFE',
          'fields': <FormMap>[
            {
              'key': 'work_date',
              'label': 'تاریخ اضافه‌کار',
              'type': 'Date',
              'default_source': 'today',
              'required': true,
              'span': 2,
            },
            {
              'key': 'start_time',
              'label': 'ساعت شروع',
              'type': 'Time',
              'required': true,
              'help': 'ساعت را از ساعت‌گزین انتخاب کنید.',
              'span': 1,
            },
            {
              'key': 'end_time',
              'label': 'ساعت پایان',
              'type': 'Time',
              'required': true,
              'next_day_allowed': true,
              'time_after': 'start_time',
              'time_after_message': hrOvertimeOrderMessage,
              'help': 'برای اضافه‌کار تا بعد از نیمه‌شب، «روز بعد» را فعال کنید.',
              'span': 1,
            },
            {
              'key': 'purpose',
              'label': 'شرح کار',
              'type': 'LongText',
              'required': true,
              'max_length': 2000,
              'span': 2,
            },
          ],
        },
        {
          'id': 'notes_details',
          'title': 'توضیحات',
          'icon': 'notes',
          'color': '#FFF0DD',
          'fields': <FormMap>[
            {
              'key': 'notes',
              'label': 'توضیحات تکمیلی',
              'type': 'LongText',
              'max_length': 2000,
              'sensitive': true,
              'span': 2,
            },
          ],
        },
        {
          'id': 'attachments',
          'title': 'پیوست‌ها',
          'icon': 'attach_file',
          'color': '#E6F6F7',
          'fields': <FormMap>[
            {
              'key': 'attachments',
              'label': 'پیوست‌ها',
              'type': 'File',
              'span': 2,
              'help': 'در صورت نیاز، فایل را مطابق محدودیت‌های سامانه اضافه کنید.',
            },
          ],
        },
        hrApprovalFlowSection(),
      ],
      'rules': <FormMap>[],
      'access': {'mode': 'all', 'roles': <String>[], 'departments': <String>[]},
    };
