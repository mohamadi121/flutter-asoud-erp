import '../form_repository.dart';

FormMap hrTrainingPreset() => {
      'schema_version': 2,
      'format': 1,
      'kind': 'Request',
      'id': 'hr_training_request',
      'title': 'درخواست آموزش کارکنان',
      'display_title': 'درخواست آموزش',
      'module': 'HR',
      'direction': 'rtl',
      'icon': 'school',
      'color': '#1876D2',
      'description': 'ثبت درخواست شرکت در دوره موجود یا پیشنهاد آموزش جدید',
      'sections': <FormMap>[
        {
          'id': 'applicant',
          'title': 'مشخصات متقاضی',
          'icon': 'person',
          'color': '#E8F2FF',
          'fields': <FormMap>[
            {
              'key': 'applicant_name',
              'label': 'نام و نام خانوادگی',
              'type': 'Display',
              'readonly': true,
              'span': 2,
              'system_source': 'current_employee.full_name',
            },
            {
              'key': 'organization_unit',
              'label': 'واحد سازمانی',
              'type': 'Display',
              'readonly': true,
              'span': 1,
              'system_source': 'current_employee.department',
            },
            {
              'key': 'organization_position',
              'label': 'سمت سازمانی',
              'type': 'Display',
              'readonly': true,
              'span': 1,
              'system_source': 'current_employee.designation',
            },
          ],
        },
        {
          'id': 'training',
          'title': 'مشخصات آموزش',
          'icon': 'school',
          'color': '#F2EAFE',
          'fields': <FormMap>[
            {
              'key': 'request_type',
              'label': 'نوع درخواست',
              'type': 'Select',
              'required': true,
              'default': 'existing_course',
              'span': 2,
              'options': <FormMap>[
                {'id': 'existing_course', 'label': 'شرکت در دوره آموزشی موجود'},
                {'id': 'new_training', 'label': 'پیشنهاد آموزش جدید'},
              ],
            },
            {
              'key': 'training_course',
              'label': 'دوره آموزشی',
              'type': 'Link',
              'source': 'Training Course',
              'span': 2,
              'help': 'فقط دوره‌های معتبر و قابل درخواست نمایش داده می‌شوند.',
              'system_source': 'training.available_courses',
            },
            {
              'key': 'proposed_training_title',
              'label': 'عنوان آموزش پیشنهادی',
              'type': 'Text',
              'span': 2,
              'help': 'عنوان دوره یا کارگاه',
            },
            {
              'key': 'proposed_provider',
              'label': 'برگزارکننده پیشنهادی',
              'type': 'Text',
              'span': 2,
              'help': 'نام مرکز یا مدرس پیشنهادی',
            },
            {
              'key': 'training_goal',
              'label': 'هدف از آموزش',
              'type': 'Select',
              'required': true,
              'span': 2,
              'options': <FormMap>[
                {'id': 'job_skill', 'label': 'ارتقای مهارت شغلی'},
                {'id': 'specialized', 'label': 'آموزش تخصصی'},
                {'id': 'mandatory', 'label': 'آموزش الزامی سازمان'},
                {'id': 'other', 'label': 'سایر موارد'},
              ],
            },
            {
              'key': 'training_goal_details',
              'label': 'شرح هدف',
              'type': 'LongText',
              'span': 2,
            },
          ],
        },
        {
          'id': 'schedule',
          'title': 'زمان و نحوه برگزاری',
          'icon': 'calendar',
          'color': '#E5F7EF',
          'fields': <FormMap>[
            {
              'key': 'delivery_method',
              'label': 'شیوه برگزاری',
              'type': 'Select',
              'span': 2,
              'options': <FormMap>[
                {'id': 'online', 'label': 'آنلاین'},
                {'id': 'in_person', 'label': 'حضوری'},
                {'id': 'hybrid', 'label': 'ترکیبی'},
              ],
            },
            {
              'key': 'proposed_start_date',
              'label': 'تاریخ شروع',
              'type': 'Date',
              'span': 1,
            },
            {
              'key': 'proposed_end_date',
              'label': 'تاریخ پایان',
              'type': 'Date',
              'span': 1,
              'after_or_equal': 'proposed_start_date',
            },
          ],
        },
        {
          'id': 'cost',
          'title': 'هزینه آموزش',
          'icon': 'payments',
          'color': '#FFF0DD',
          'fields': <FormMap>[
            {
              'key': 'cost_status',
              'label': 'وضعیت هزینه پیشنهادی',
              'type': 'Select',
              'required': true,
              'default': 'unknown',
              'span': 2,
              'options': <FormMap>[
                {'id': 'unknown', 'label': 'هنوز مشخص نیست'},
                {'id': 'no_cost', 'label': 'بدون هزینه'},
                {'id': 'known_cost', 'label': 'دارای هزینه مشخص'},
              ],
            },
            {
              'key': 'estimated_cost',
              'label': 'مبلغ برآوردی',
              'type': 'Money',
              'min': 0.01,
              'span': 2,
              'help': 'ثبت هزینه، به‌معنای تأیید مالی، خرید دوره یا پرداخت وجه نیست.',
            },
          ],
        },
        {
          'id': 'notes',
          'title': 'توضیحات تکمیلی',
          'icon': 'notes',
          'color': '#E6F6F7',
          'fields': <FormMap>[
            {
              'key': 'additional_notes',
              'label': 'توضیحات تکمیلی',
              'type': 'LongText',
              'span': 2,
              'help': 'دلیل نیاز به دوره، کاربرد آموزشی یا توضیحات بیشتر...',
            },
          ],
        },
      ],
      'rules': <FormMap>[
        {
          'target': 'training_course',
          'action': 'visible',
          'join': 'and',
          'conditions': <FormMap>[
            {'field': 'request_type', 'op': 'eq', 'value': 'existing_course'},
          ],
        },
        {
          'target': 'training_course',
          'action': 'required',
          'join': 'and',
          'conditions': <FormMap>[
            {'field': 'request_type', 'op': 'eq', 'value': 'existing_course'},
          ],
        },
        {
          'target': 'proposed_training_title',
          'action': 'visible',
          'join': 'and',
          'conditions': <FormMap>[
            {'field': 'request_type', 'op': 'eq', 'value': 'new_training'},
          ],
        },
        {
          'target': 'proposed_training_title',
          'action': 'required',
          'join': 'and',
          'conditions': <FormMap>[
            {'field': 'request_type', 'op': 'eq', 'value': 'new_training'},
          ],
        },
        {
          'target': 'proposed_provider',
          'action': 'visible',
          'join': 'and',
          'conditions': <FormMap>[
            {'field': 'request_type', 'op': 'eq', 'value': 'new_training'},
          ],
        },
        {
          'target': 'training_goal_details',
          'action': 'visible',
          'join': 'and',
          'conditions': <FormMap>[
            {'field': 'training_goal', 'op': 'eq', 'value': 'other'},
          ],
        },
        {
          'target': 'training_goal_details',
          'action': 'required',
          'join': 'and',
          'conditions': <FormMap>[
            {'field': 'training_goal', 'op': 'eq', 'value': 'other'},
          ],
        },
        {
          'target': 'estimated_cost',
          'action': 'visible',
          'join': 'and',
          'conditions': <FormMap>[
            {'field': 'cost_status', 'op': 'eq', 'value': 'known_cost'},
          ],
        },
        {
          'target': 'estimated_cost',
          'action': 'required',
          'join': 'and',
          'conditions': <FormMap>[
            {'field': 'cost_status', 'op': 'eq', 'value': 'known_cost'},
          ],
        },
      ],
      'access': {'mode': 'all', 'roles': <String>[], 'departments': <String>[]},
    };
