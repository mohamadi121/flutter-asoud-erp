import '../form_repository.dart';
import 'hr_period_common.dart';

/// Raw reusable mission request (daily or half-day); holidays are never selectable.
FormMap hrMissionPreset() => {
      'schema_version': 2,
      'kind': 'Request',
      'title': 'درخواست مأموریت',
      'module': 'HR',
      'icon': 'briefcase',
      'color': '#2E7D32',
      'description': 'قالب خام درخواست مأموریت اداری روزانه یا نیم‌روز',
      'sections': <FormMap>[
        hrApplicantSection(),
        {
          'id': 'mission_details',
          'title': 'مشخصات مأموریت',
          'icon': 'flight_takeoff',
          'color': '#E5F7EF',
          'fields': <FormMap>[
            {
              'key': 'destination',
              'label': 'مقصد مأموریت',
              'type': 'Text',
              'required': true,
              'max_length': 250,
              'span': 2,
            },
            {
              'key': 'purpose',
              'label': 'هدف مأموریت',
              'type': 'LongText',
              'required': true,
              'max_length': 2000,
              'span': 2,
            },
            ...hrDateRangeFields(),
            {
              'key': 'shift',
              'label': 'شیفت مرتبط',
              'type': 'Link',
              'source': 'Shift Type',
              'span': 2,
              'help': 'اگر در این بازه بیش از یک شیفت دارید، شیفت مرتبط را انتخاب کنید.',
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
      'rules': hrHalfDayRules(),
      'access': {'mode': 'all', 'roles': <String>[], 'departments': <String>[]},
    };
