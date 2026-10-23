import '../form_repository.dart';

FormMap employmentCertificatePreset() => {
      'schema_version': 2,
      'format': 1,
      'kind': 'Request',
      'title': 'درخواست گواهی اشتغال به کار',
      'module': 'HR',
      'icon': 'badge',
      'color': '#6D5BD0',
      'description': 'ثبت درخواست گواهی اشتغال به کار',
      'layout': 'sections',
      // Issued automatically after the final approval (backend `certificate_issue`).
      'execution': {'kind': 'certificate_issue'},
      'access': {'mode': 'all', 'roles': [], 'departments': []},
      'sections': [
        {
          'id': 'applicant',
          'title': 'مشخصات متقاضی',
          'color': '#E8F2FF',
          'icon': 'person',
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
          'id': 'certificate_details',
          'title': 'مشخصات گواهی درخواستی',
          'color': '#F2EAFE',
          'icon': 'badge',
          'fields': [
            {
              'key': 'recipient',
              'execution_key': 'recipient',
              'label': 'مرجع دریافت‌کننده گواهی',
              'type': 'Text',
              'required': true,
              'help': 'نام بانک، سفارت، سازمان یا شرکت',
              'max_length': 250,
            },
            {
              'key': 'purpose',
              'execution_key': 'purpose',
              'label': 'هدف از دریافت گواهی',
              'type': 'Select',
              'required': true,
              'options': [
                {'id': 'bank', 'label': 'ارائه به بانک'},
                {'id': 'embassy', 'label': 'ارائه به سفارت'},
                {'id': 'organization', 'label': 'ارائه به سازمان یا شرکت'},
                {'id': 'other', 'label': 'سایر موارد'},
              ],
            },
            {
              'key': 'purpose_details',
              'execution_key': 'purpose_details',
              'label': 'شرح هدف',
              'type': 'LongText',
              'max_length': 1000,
            },
            {
              'key': 'certificate_language',
              'execution_key': 'language',
              'label': 'زبان گواهی',
              'type': 'Select',
              'required': true,
              'default': 'persian',
              'style': 'radio',
              'options': [
                {'id': 'persian', 'label': 'فارسی'},
                {'id': 'english', 'label': 'انگلیسی'},
              ],
            },
            {
              'key': 'include_compensation',
              'execution_key': 'include_compensation',
              'label': 'درج حقوق و مزایا در گواهی',
              'type': 'Select',
              'required': true,
              'default': 'no',
              'style': 'radio',
              'options': [
                {'id': 'no', 'label': 'خیر'},
                {'id': 'yes', 'label': 'بله'},
              ],
            },
            {
              'key': 'compensation_notice',
              'label': 'اطلاع‌رسانی',
              'type': 'Display',
              'default': 'درج اطلاعات حقوق و مزایا پس از بررسی مجوز و دریافت اطلاعات معتبر انجام می‌شود.',
            },
          ],
        },
        {
          'id': 'delivery',
          'title': 'نحوه دریافت گواهی',
          'color': '#E5F7EF',
          'icon': 'download',
          'fields': [
            {
              'key': 'delivery_method',
              'label': 'روش دریافت پیشنهادی',
              'type': 'Select',
              'required': true,
              'default': 'electronic',
              'style': 'radio',
              'options': [
                {'id': 'electronic', 'label': 'نسخه الکترونیکی'},
                {'id': 'printed', 'label': 'نسخه چاپی'},
                {'id': 'both', 'label': 'هر دو'},
              ],
            },
          ],
        },
        {
          'id': 'additional_notes',
          'title': 'توضیحات تکمیلی',
          'color': '#FFF0DD',
          'icon': 'notes',
          'fields': [
            {
              'key': 'additional_notes',
              'label': 'توضیحات تکمیلی',
              'type': 'LongText',
              'max_length': 2000,
            },
          ],
        },
        {
          'id': 'approval_issuance',
          'title': 'گردش تأیید و صدور',
          'color': '#FCE9EE',
          'icon': 'account_tree',
          'fields': [
            {
              'key': 'workflow_notice',
              'label': 'گردش تأیید و صدور',
              'type': 'Display',
              'default': 'مسیر بررسی از گردش کار تعریف‌شده تعیین می‌شود.',
            },
            {
              'key': 'preview_notice',
              'label': 'یادآوری',
              'type': 'Display',
              'default': 'این صفحه پیش‌نمایش درخواست است، نه متن گواهی صادرشده. صدور سند واقعی به داده معتبر، مجوز و قالب سند نیاز دارد.',
            },
          ],
        },
      ],
      'rules': [
        {
          'target': 'purpose_details',
          'action': 'visible',
          'join': 'and',
          'conditions': [
            {'field': 'purpose', 'op': 'eq', 'value': 'other'},
          ],
        },
        {
          'target': 'purpose_details',
          'action': 'required',
          'join': 'and',
          'conditions': [
            {'field': 'purpose', 'op': 'eq', 'value': 'other'},
          ],
        },
        {
          'target': 'compensation_notice',
          'action': 'visible',
          'join': 'and',
          'conditions': [
            {'field': 'include_compensation', 'op': 'eq', 'value': 'yes'},
          ],
        },
      ],
    };
