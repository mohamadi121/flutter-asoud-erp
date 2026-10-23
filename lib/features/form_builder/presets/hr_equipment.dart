import '../form_repository.dart';

/// الگوی خام درخواست دریافت یا عودت تجهیزات، مستقل از گردش کار و عملیات انبار.
FormMap hrEquipmentPreset() => {
      'schema_version': 2,
      'format': 1,
      'kind': 'Request',
      'title': 'درخواست تحویل یا عودت تجهیزات',
      'module': 'HR',
      'icon': 'box',
      'color': '#1876D2',
      'description':
          'ثبت درخواست دریافت یا عودت چند قلم تجهیز بدون اجرای عملیات انبار یا اموال',
      'access': {'mode': 'all', 'roles': [], 'departments': []},
      'sections': [
        {
          'id': 'applicant',
          'title': 'مشخصات متقاضی',
          'icon': 'person',
          'color': '#1876D2',
          'background_color': '#E8F2FF',
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
              'type': 'Display',
              'readonly': true,
              'span': 1,
              'system_source': 'employee_designation',
            },
          ],
        },
        {
          'id': 'request_type',
          'title': 'نوع درخواست',
          'icon': 'swap_horiz',
          'color': '#7B1FA2',
          'background_color': '#F2EAFE',
          'fields': [
            {
              'key': 'equipment_request_type',
              'label': 'نوع درخواست',
              'type': 'Select',
              'required': true,
              'default': 'receive_equipment',
              'options': [
                {'id': 'receive_equipment', 'label': 'دریافت تجهیزات'},
                {'id': 'return_equipment', 'label': 'عودت تجهیزات'},
              ],
            },
          ],
        },
        {
          'id': 'equipment',
          'title': 'تجهیزات',
          'icon': 'inventory_2',
          'color': '#1876D2',
          'background_color': '#E8F2FF',
          'fields': [
            {
              'key': 'requested_equipment',
              'label': 'تجهیزات مورد درخواست',
              'type': 'Table',
              'required': true,
              'min_rows': 1,
              'max_rows': 100,
              'columns': [
                {
                  'key': 'item',
                  'label': 'کالا یا تجهیز',
                  'type': 'Link',
                  'source': 'Item',
                  'required': true,
                },
                {
                  'key': 'quantity',
                  'label': 'تعداد',
                  'type': 'Integer',
                  'required': true,
                  'default': 1,
                  'min': 1,
                  'max': 999999,
                },
                {
                  'key': 'item_details',
                  'label': 'مشخصات تکمیلی کالا',
                  'type': 'LongText',
                },
              ],
            },
            {
              'key': 'requested_equipment_total',
              'label': 'جمع تعداد تجهیزات',
              'type': 'Formula',
              'readonly': true,
              'formula': {
                'op': 'sum',
                'table': 'requested_equipment',
                'columns': ['quantity'],
                'precision': 0,
              },
            },
            {
              'key': 'returnable_equipment',
              'label': 'تجهیزات قابل عودت',
              'type': 'Table',
              'required': true,
              'min_rows': 1,
              'max_rows': 100,
              'columns': [
                {
                  'key': 'equipment_reference',
                  'label': 'تجهیز در اختیار شما',
                  'type': 'Link',
                  'source': 'Item',
                  'required': true,
                  'system_source': 'employee_equipment_assignment',
                },
                {
                  'key': 'quantity',
                  'label': 'تعداد',
                  'type': 'Integer',
                  'required': true,
                  'default': 1,
                  'min': 1,
                  'max': 999999,
                },
                {
                  'key': 'reported_condition',
                  'label': 'وضعیت تجهیز از نظر متقاضی',
                  'type': 'Select',
                  'required': true,
                  'default': 'needs_review',
                  'options': [
                    {'id': 'healthy', 'label': 'سالم'},
                    {'id': 'damaged', 'label': 'دارای آسیب یا ایراد'},
                    {'id': 'needs_review', 'label': 'نیازمند بررسی مسئول'},
                  ],
                },
                {
                  'key': 'equipment_notes',
                  'label': 'توضیحات تجهیز',
                  'type': 'LongText',
                },
              ],
            },
            {
              'key': 'returnable_equipment_total',
              'label': 'جمع تعداد تجهیزات انتخاب‌شده',
              'type': 'Formula',
              'readonly': true,
              'formula': {
                'op': 'sum',
                'table': 'returnable_equipment',
                'columns': ['quantity'],
                'precision': 0,
              },
            },
          ],
        },
        {
          'id': 'reason_schedule',
          'title': 'دلیل و زمان‌بندی پیشنهادی',
          'icon': 'event',
          'color': '#2E7D32',
          'background_color': '#E5F7EF',
          'fields': [
            {
              'key': 'receive_reason',
              'label': 'دلیل درخواست',
              'type': 'Select',
              'required': true,
              'options': [
                {'id': 'work_need', 'label': 'نیاز کاری'},
                {'id': 'replacement', 'label': 'جایگزینی تجهیز'},
                {'id': 'project_need', 'label': 'نیاز پروژه'},
                {'id': 'other', 'label': 'سایر موارد'},
              ],
            },
            {
              'key': 'other_receive_reason',
              'label': 'شرح دلیل',
              'type': 'LongText',
            },
            {
              'key': 'needed_date',
              'label': 'تاریخ موردنیاز',
              'type': 'Date',
            },
            {
              'key': 'suggested_return_date',
              'label': 'تاریخ پیشنهادی عودت',
              'type': 'Date',
            },
          ],
        },
        {
          'id': 'notes',
          'title': 'توضیحات تکمیلی',
          'icon': 'notes',
          'color': '#F57F17',
          'background_color': '#FFF0DD',
          'fields': [
            {
              'key': 'general_notes',
              'label': 'توضیحات تکمیلی',
              'type': 'LongText',
              'placeholder':
                  'مشخصات فنی موردنیاز، علت آسیب یا توضیحات بیشتر...',
            },
          ],
        },
      ],
      'rules': [
        {
          'target': 'requested_equipment',
          'action': 'visible',
          'join': 'and',
          'conditions': [
            {
              'field': 'equipment_request_type',
              'op': 'eq',
              'value': 'receive_equipment'
            },
          ],
        },
        {
          'target': 'requested_equipment_total',
          'action': 'visible',
          'join': 'and',
          'conditions': [
            {
              'field': 'equipment_request_type',
              'op': 'eq',
              'value': 'receive_equipment'
            },
          ],
        },
        {
          'target': 'returnable_equipment',
          'action': 'visible',
          'join': 'and',
          'conditions': [
            {
              'field': 'equipment_request_type',
              'op': 'eq',
              'value': 'return_equipment'
            },
          ],
        },
        {
          'target': 'returnable_equipment_total',
          'action': 'visible',
          'join': 'and',
          'conditions': [
            {
              'field': 'equipment_request_type',
              'op': 'eq',
              'value': 'return_equipment'
            },
          ],
        },
        {
          'target': 'receive_reason',
          'action': 'visible',
          'join': 'and',
          'conditions': [
            {
              'field': 'equipment_request_type',
              'op': 'eq',
              'value': 'receive_equipment'
            },
          ],
        },
        {
          'target': 'other_receive_reason',
          'action': 'visible',
          'join': 'and',
          'conditions': [
            {'field': 'receive_reason', 'op': 'eq', 'value': 'other'},
          ],
        },
        {
          'target': 'other_receive_reason',
          'action': 'required',
          'join': 'and',
          'conditions': [
            {'field': 'receive_reason', 'op': 'eq', 'value': 'other'},
          ],
        },
        {
          'target': 'needed_date',
          'action': 'visible',
          'join': 'and',
          'conditions': [
            {
              'field': 'equipment_request_type',
              'op': 'eq',
              'value': 'receive_equipment'
            },
          ],
        },
        {
          'target': 'suggested_return_date',
          'action': 'visible',
          'join': 'and',
          'conditions': [
            {
              'field': 'equipment_request_type',
              'op': 'eq',
              'value': 'return_equipment'
            },
          ],
        },
      ],
    };
