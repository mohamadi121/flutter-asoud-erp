import '../form_editor/editor_widgets.dart';
import '../form_repository.dart';

/// الگوی خام و قابل استفادهٔ مجدد درخواست مساعده منابع انسانی.
FormMap hrSalaryAdvancePreset() => {
      ...blankSchema('Request'),
      'title': 'درخواست مساعده',
      'module': 'HR',
      'icon': 'wallet',
      'color': '#7B1FA2',
      'description': 'قالب خام ثبت مبلغ و پیشنهاد تسویه مساعده کارکنان',
      'sections': [
        {
          'id': 'applicant',
          'title': 'مشخصات متقاضی',
          'color': '#E8F2FF',
          'fields': [
            {
              'key': 'applicant_full_name',
              'label': 'نام و نام خانوادگی',
              'type': 'Text',
              'source_mode': 'asoud',
              'source': 'Employee',
              'readonly': true,
              'default': 'دریافت خودکار',
              'span': 2,
            },
            {
              'key': 'applicant_department',
              'label': 'واحد سازمانی',
              'type': 'Text',
              'source_mode': 'asoud',
              'source': 'Department',
              'readonly': true,
              'default': 'دریافت خودکار',
              'span': 1,
            },
            {
              'key': 'applicant_position',
              'label': 'سمت سازمانی',
              'type': 'Text',
              'source_mode': 'asoud',
              'readonly': true,
              'default': 'دریافت خودکار',
              'span': 1,
            },
          ],
        },
        {
          'id': 'advance_details',
          'title': 'مشخصات مساعده',
          'color': '#F2EAFE',
          'fields': [
            {
              'key': 'requested_amount',
              'label': 'مبلغ مساعده درخواستی',
              'type': 'Money',
              'required': true,
              'min': 0.01,
              'span': 2,
              'help': 'مبلغ مطابق تنظیمات پایه و واحد پول سازمان ثبت می‌شود.',
            },
            {
              'key': 'advance_reason',
              'label': 'دلیل درخواست مساعده',
              'type': 'Select',
              'required': true,
              'span': 2,
              'options': [
                {'id': 'essential_personal_expenses', 'label': 'هزینه‌های ضروری شخصی'},
                {'id': 'medical_expenses', 'label': 'هزینه درمان'},
                {'id': 'housing_expenses', 'label': 'هزینه مسکن'},
                {'id': 'other', 'label': 'سایر موارد'},
              ],
            },
            {
              'key': 'reason_detail',
              'label': 'شرح دلیل درخواست',
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
        {
          'id': 'repayment_proposal',
          'title': 'پیشنهاد نحوه تسویه',
          'color': '#FFF0DD',
          'fields': [
            {
              'key': 'repayment_method',
              'label': 'روش تسویه پیشنهادی',
              'type': 'Select',
              'required': true,
              'span': 2,
              'options': [
                {'id': 'payroll_deduction', 'label': 'کسر از حقوق'},
                {'id': 'direct_repayment', 'label': 'بازپرداخت مستقیم'},
                {'id': 'finance_decision', 'label': 'مطابق تصمیم امور مالی'},
              ],
            },
            {
              'key': 'installment_count',
              'label': 'تعداد اقساط پیشنهادی',
              'type': 'Select',
              'span': 1,
              'options': [
                {'id': 'installments_1', 'label': '۱ قسط'},
                {'id': 'installments_2', 'label': '۲ قسط'},
                {'id': 'installments_3', 'label': '۳ قسط'},
                {'id': 'installments_4', 'label': '۴ قسط'},
                {'id': 'installments_5', 'label': '۵ قسط'},
                {'id': 'installments_6', 'label': '۶ قسط'},
                {'id': 'installments_9', 'label': '۹ قسط'},
                {'id': 'installments_12', 'label': '۱۲ قسط'},
              ],
            },
            for (final count in [1, 2, 3, 4, 5, 6, 9, 12])
              {
                'key': 'estimated_installment_$count',
                'label': 'مبلغ تقریبی هر قسط',
                'type': 'Formula',
                'span': 1,
                'formula': {'expression': 'requested_amount / $count', 'precision': 0},
              },
            {
              'key': 'installment_estimate_notice',
              'label': 'توضیح برآورد قسط',
              'type': 'Display',
              'span': 2,
              'default': 'این مبلغ صرفاً برآورد اولیه است و برنامه قطعی کسر از حقوق محسوب نمی‌شود.',
            },
          ],
        },
        {
          'id': 'attachments',
          'title': 'پیوست‌ها',
          'color': '#E6F6F7',
          'fields': [
            {
              'key': 'attachments',
              'label': 'پیوست‌ها',
              'type': 'File',
              'span': 2,
              'help': 'در صورت نیاز، فایل را مطابق محدودیت‌های سامانه اضافه کنید.',
            },
          ],
        },
        {
          'id': 'approval_flow',
          'title': 'گردش تأیید',
          'color': '#FCE9EE',
          'fields': [
            {
              'key': 'approval_flow_notice',
              'label': 'گردش تأیید',
              'type': 'Display',
              'span': 2,
              'default': 'مراحل و مسئولان رسیدگی از گردش کار پیکربندی‌شده سازمان تعیین می‌شوند.',
            },
          ],
        },
        {
          'id': 'review_and_submit',
          'title': 'بررسی نهایی و ارسال',
          'color': '#E8F2FF',
          'fields': [
            {
              'key': 'review_notice',
              'label': 'بررسی و ادامه',
              'type': 'Display',
              'span': 2,
              'default': 'روش بازپرداخت، مبلغ مصوب و پرداخت واقعی پس از رسیدگی توسط مسئولان مجاز تعیین می‌شود.',
            },
          ],
        },
      ],
      'rules': [
        {
          'target': 'reason_detail',
          'action': 'visible',
          'join': 'and',
          'conditions': [
            {'field': 'advance_reason', 'op': 'eq', 'value': 'other'},
          ],
        },
        {
          'target': 'reason_detail',
          'action': 'required',
          'join': 'and',
          'conditions': [
            {'field': 'advance_reason', 'op': 'eq', 'value': 'other'},
          ],
        },
        {
          'target': 'installment_count',
          'action': 'visible',
          'join': 'and',
          'conditions': [
            {'field': 'repayment_method', 'op': 'eq', 'value': 'payroll_deduction'},
          ],
        },
        {
          'target': 'installment_count',
          'action': 'required',
          'join': 'and',
          'conditions': [
            {'field': 'repayment_method', 'op': 'eq', 'value': 'payroll_deduction'},
          ],
        },
        for (final count in [1, 2, 3, 4, 5, 6, 9, 12])
          {
            'target': 'estimated_installment_$count',
            'action': 'visible',
            'join': 'and',
            'conditions': [
              {'field': 'repayment_method', 'op': 'eq', 'value': 'payroll_deduction'},
              {'field': 'installment_count', 'op': 'eq', 'value': 'installments_$count'},
            ],
          },
        {
          'target': 'installment_estimate_notice',
          'action': 'visible',
          'join': 'and',
          'conditions': [
            {'field': 'repayment_method', 'op': 'eq', 'value': 'payroll_deduction'},
            {'field': 'installment_count', 'op': 'not_empty'},
          ],
        },
      ],
    };
