import '../form_repository.dart';

/// الگوی خام آغاز درخواست تسویه‌حساب؛ مسیر رسیدگی را گردش کار تعیین می‌کند.
FormMap hrSettlementPreset() => {
      'schema_version': 2,
      'format': 1,
      'kind': 'Request',
      'title': 'درخواست تسویه‌حساب پرسنل',
      'short_title': 'درخواست تسویه‌حساب',
      'module': 'HR',
      'icon': 'assignment_turned_in',
      'color': '#1876D2',
      'description': 'آغاز درخواست بررسی تسویه‌حساب پرسنل',
      'sections': [
        {
          'id': 'personnel_details',
          'title': 'مشخصات پرسنلی',
          'icon': 'badge',
          'color': '#E8F2FF',
          'fields': [
            _systemField('employee_full_name', 'نام و نام خانوادگی', 'full_name', span: 2),
            _systemField('employee_code', 'کد پرسنلی', 'employee_number', span: 1),
            _systemField('organization_unit', 'واحد سازمانی', 'department', span: 1),
            _systemField('organization_position', 'سمت سازمانی', 'designation', span: 1),
            _systemField('employment_start_date', 'تاریخ شروع همکاری', 'current_employment_start_date', span: 1),
          ],
        },
        {
          'id': 'settlement_request_details',
          'title': 'مشخصات درخواست تسویه',
          'icon': 'assignment',
          'color': '#F2EAFE',
          'fields': [
            {
              'key': 'settlement_reason',
              'label': 'علت درخواست',
              'type': 'Select',
              'required': true,
              'options': [
                {'id': 'resignation', 'label': 'استعفا'},
                {'id': 'contract_end', 'label': 'پایان قرارداد'},
                {'id': 'retirement', 'label': 'بازنشستگی'},
                {'id': 'other_termination', 'label': 'سایر موارد خاتمه همکاری'},
                {'id': 'other', 'label': 'سایر موارد'},
              ],
            },
            {
              'key': 'reason_description',
              'label': 'شرح علت',
              'type': 'LongText',
              'help': 'شرح علت درخواست را وارد کنید.',
              'max_length': 5000,
            },
            {
              'key': 'proposed_end_date',
              'label': 'تاریخ پیشنهادی پایان همکاری',
              'type': 'Date',
              'required': true,
              'help': 'این تاریخ پیشنهادی است و تا زمان تأیید مراجع دارای اختیار، تاریخ قطعی پایان همکاری محسوب نمی‌شود.',
            },
          ],
        },
        {
          'id': 'property_handover_status',
          'title': 'وضعیت تحویل اموال و تجهیزات',
          'icon': 'inventory_2',
          'color': '#E5F7EF',
          'description': 'این انتخاب صرفاً اعلام متقاضی است. تأیید نهایی وضعیت اموال و تجهیزات توسط واحد مسئول انجام می‌شود.',
          'fields': [
            {
              'key': 'property_declaration',
              'label': 'وضعیت اولیه از نظر متقاضی',
              'type': 'Select',
              'required': true,
              'default': 'needs_review',
              'options': [
                {'id': 'all_returned', 'label': 'تمام اموال تحویل داده شده‌اند.'},
                {'id': 'items_outstanding', 'label': 'اموال یا تجهیزات تحویل‌داده‌نشده دارم.'},
                {'id': 'needs_review', 'label': 'نیازمند بررسی واحد مسئول.'},
              ],
            },
          ],
        },
        {
          'id': 'additional_notes',
          'title': 'توضیحات تکمیلی',
          'icon': 'notes',
          'color': '#FFF0DD',
          'fields': [
            {
              'key': 'additional_notes',
              'label': 'توضیحات تکمیلی',
              'type': 'LongText',
              'help': 'توضیحات مربوط به درخواست...',
              'max_length': 5000,
            },
          ],
        },
      ],
      'rules': [
        {
          'target': 'reason_description',
          'action': 'visible',
          'join': 'and',
          'conditions': [
            {'field': 'settlement_reason', 'op': 'eq', 'value': 'other'},
          ],
        },
        {
          'target': 'reason_description',
          'action': 'required',
          'join': 'and',
          'conditions': [
            {'field': 'settlement_reason', 'op': 'eq', 'value': 'other'},
          ],
        },
      ],
      'access': {'mode': 'all', 'roles': [], 'departments': []},
    };

FormMap _systemField(String key, String label, String systemField, {required int span}) => {
      'key': key,
      'label': label,
      'type': 'Text',
      'readonly': true,
      'source_mode': 'asoud',
      'source': 'Employee',
      'system_field': systemField,
      'span': span,
    };
