import '../form_repository.dart';
import 'hr_period_common.dart';

/// Raw reusable leave request; the approval route and the execution are set in the editor.
FormMap hrLeavePreset() => {
      'schema_version': 2,
      'kind': 'Request',
      'title': 'درخواست مرخصی',
      'module': 'HR',
      'icon': 'calendar',
      'color': '#2E7D32',
      'description': 'قالب خام درخواست مرخصی روزانه یا نیم‌روز با نوع مرخصی واقعی',
      'sections': <FormMap>[
        hrApplicantSection(),
        {
          'id': 'leave_details',
          'title': 'مشخصات مرخصی',
          'icon': 'event_available',
          'color': '#E5F7EF',
          'fields': <FormMap>[
            {
              'key': 'leave_type',
              'label': 'نوع مرخصی',
              'type': 'Link',
              'source': 'Leave Type',
              'required': true,
              'span': 2,
            },
            ...hrDateRangeFields(),
          ],
        },
        {
          'id': 'description',
          'title': 'توضیحات',
          'icon': 'notes',
          'color': '#FFF0DD',
          'fields': <FormMap>[
            {
              'key': 'description',
              'label': 'توضیح درخواست مرخصی',
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
              'sensitive': true,
              'span': 2,
              'help': 'گواهی پزشکی یا مدرک دیگر را در صورت نیاز اضافه کنید؛ فقط شما و منابع انسانی آن را می‌بینید.',
            },
          ],
        },
        hrApprovalFlowSection(),
      ],
      'rules': hrHalfDayRules(),
      'access': {'mode': 'all', 'roles': <String>[], 'departments': <String>[]},
    };
