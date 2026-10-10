const erpNextRoleLabels = <String, String>{
  '__direct_manager__': 'مدیر مستقیم',
  '__initiator__': 'درخواست‌کننده',
  'Administrator': 'مدیر سامانه',
  'System Manager': 'مدیر سیستم',
  'Accounts Manager': 'مدیر مالی',
  'Accounts User': 'کارشناس مالی',
  'Purchase Manager': 'مدیر خرید',
  'Purchase User': 'کارشناس خرید',
  'Stock Manager': 'مدیر انبار',
  'Stock User': 'کارشناس انبار',
  'Sales Manager': 'مدیر فروش',
  'Sales User': 'کارشناس فروش',
  'HR Manager': 'مدیر منابع انسانی',
  'HR User': 'کارشناس منابع انسانی',
  'HR_MANAGER': 'مدیر منابع انسانی',
  'HR_USER': 'کارشناس منابع انسانی',
  'SYSTEM_ADMIN': 'مدیر سیستم',
  'SYS_ADMIN': 'مدیر سیستم',
  'FINANCE_MANAGER': 'مدیر مالی',
  'FIN_MGR': 'مدیر مالی',
  'ACCOUNTANT': 'حسابدار',
  'Support Team': 'کارشناس پشتیبانی',
  'Projects Manager': 'مدیر پروژه',
  'Employee': 'کارمند',
  'Employee Self Service': 'خودخدمت کارمند',
  'Leave Approver': 'تأییدکننده مرخصی',
  'Expense Approver': 'تأییدکننده هزینه',
  'Shift Manager': 'مدیر شیفت',
  'Projects User': 'کارشناس پروژه',
  'Manufacturing Manager': 'مدیر تولید',
  'Manufacturing User': 'کارشناس تولید',
  'Maintenance Manager': 'مدیر نگهداری',
  'Maintenance User': 'کارشناس نگهداری',
  'Quality Manager': 'مدیر کیفیت',
  'Quality Inspector': 'بازرس کیفیت',
  'Item Manager': 'مدیر کالا',
  'Sales Master Manager': 'مدیر اطلاعات پایه فروش',
  'Fleet Manager': 'مدیر ناوگان',
  'Agriculture Manager': 'مدیر کشاورزی',
  'Analytics': 'تحلیل‌گر',
  'Auditor': 'حسابرس',
  'Report Manager': 'مدیر گزارش‌ها',
  'Prepared Report User': 'کاربر گزارش آماده',
  'Workspace Manager': 'مدیر فضای کاری',
  'Website Manager': 'مدیر وب‌سایت',
  'Knowledge Base Contributor': 'همکار پایگاه دانش',
  'Newsletter Manager': 'مدیر خبرنامه',
  'Blogger': 'نویسنده وبلاگ',
  'Translator': 'مترجم',
  'Script Manager': 'مدیر اسکریپت',
  'Customer': 'مشتری',
  'Supplier': 'تأمین‌کننده',
  'Desk User': 'کاربر میزکار',
  'Academics User': 'کاربر آموزش',
  'Agriculture User': 'کارشناس کشاورزی',
  'Dashboard Manager': 'مدیر داشبورد',
  'Delivery Manager': 'مدیر تحویل',
  'Delivery User': 'کارشناس تحویل',
  'Fulfillment User': 'کارشناس پردازش سفارش',
  'Inbox User': 'کاربر صندوق پیام',
  'Interviewer': 'مصاحبه‌کننده',
  'Knowledge Base Editor': 'ویرایشگر پایگاه دانش',
  'Purchase Master Manager': 'مدیر اطلاعات پایه خرید',
  'Stock Master Manager': 'مدیر اطلاعات پایه انبار',
  'Purchase Master User': 'کارشناس اطلاعات پایه خرید',
  'Sales Master User': 'کارشناس اطلاعات پایه فروش',
  'Loan Manager': 'مدیر وام',
  'Payroll Manager': 'مدیر حقوق و دستمزد',
  'Payroll User': 'کارشناس حقوق و دستمزد',
  'Attendance Tool User': 'کاربر ابزار حضور و غیاب',
  'All': 'همه',
  'Guest': 'مهمان',
};

String persianRoleLabel(String role) {
  if (role.trim().isEmpty) return role;
  final trimmed = role.trim();
  final direct = erpNextRoleLabels[trimmed];
  if (direct != null) return direct;

  final normalized = trimmed.replaceAll(RegExp(r'[-_]+'), ' ').toLowerCase();
  for (final entry in erpNextRoleLabels.entries) {
    if (entry.key.toLowerCase() == normalized) {
      return entry.value;
    }
  }
  return _humanizeRoleCode(trimmed);
}

/// Unknown machine codes (for example `FIELD_OPS`) are not translated, but
/// they must never reach the UI as `ALL_CAPS_WITH_UNDERSCORES`.
String _humanizeRoleCode(String value) {
  final machine = RegExp(r'^[A-Z0-9 _\-/]+$').hasMatch(value) &&
      RegExp(r'[A-Z]').hasMatch(value);
  if (!machine) return value;
  final words = value
      .replaceAll(RegExp(r'[-_]+'), ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => word.length == 1
          ? word.toUpperCase()
          : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}');
  return words.join(' ');
}

const erpNextLeaveTypes = <String, String>{
  'Casual Leave': 'مرخصی اتفاقی',
  'Compensatory Off': 'مرخصی جبرانی',
  'Leave Without Pay': 'مرخصی بدون حقوق',
  'Privilege Leave': 'مرخصی استحقاقی',
  'Sick Leave': 'مرخصی استعلاجی',
  'Maternity Leave': 'مرخصی زایمان',
  'Paternity Leave': 'مرخصی تشویقی پدر شدن',
  'Other Leave': 'سایر مرخصی‌ها',
};

String persianLeaveTypeLabel(String? type) {
  if (type == null || type.trim().isEmpty) return '';
  final trimmed = type.trim();
  final direct = erpNextLeaveTypes[trimmed];
  if (direct != null) return direct;

  final normalized = trimmed.replaceAll(RegExp(r'[-_]+'), ' ').toLowerCase();
  for (final entry in erpNextLeaveTypes.entries) {
    if (entry.key.toLowerCase() == normalized) {
      return entry.value;
    }
  }
  return trimmed;
}

const workflowStatusLabels = <String, String>{
  'Draft': 'پیش‌نویس',
  'Open': 'در انتظار اقدام',
  'Pending': 'در انتظار بررسی',
  'In Progress': 'در حال اقدام',
  'Running': 'در حال گردش',
  'Approved': 'تأییدشده',
  'Completed': 'تکمیل‌شده',
  'Rejected': 'ردشده',
  'Returned': 'بازگردانده‌شده',
  'Cancelled': 'لغوشده',
  'Closed': 'بسته‌شده',
  'Active': 'فعال',
  'Inactive': 'غیرفعال',
  'Archived': 'آرشیو',
  'Submitted': 'ارسال‌شده',
};

String persianWorkflowStatus(String? status) {
  if (status == null || status.trim().isEmpty) return '';
  final trimmed = status.trim();
  final direct = workflowStatusLabels[trimmed];
  if (direct != null) return direct;

  final normalized = trimmed.replaceAll(RegExp(r'[-_]+'), ' ').toLowerCase();
  for (final entry in workflowStatusLabels.entries) {
    if (entry.key.toLowerCase() == normalized) {
      return entry.value;
    }
  }
  return trimmed;
}

bool isInternalRole(String role) =>
    role.trim().toUpperCase().startsWith('ASOUD-ACCESS-USER-');

String formatUserGreetingRoles(Iterable<String> roles) {
  final filtered = roles
      .where((role) => !isInternalRole(role))
      .map(persianRoleLabel)
      .where((label) => label.trim().isNotEmpty)
      .toList(growable: false);
  return filtered.isEmpty ? 'کاربر سامانه' : filtered.join('، ');
}

String persianTransitionLabel(String? label) {
  if (label == null || label.trim().isEmpty) return 'ادامه';
  final trimmed = label.trim();
  if (trimmed.toLowerCase() == 'continue') return 'ادامه';
  return trimmed;
}

String persianGenderLabel(String? gender) => switch (gender) {
      'Male' => 'مرد',
      'Female' => 'زن',
      'Other' => 'سایر',
      final value => value ?? '',
    };

String persianRequestFieldTypeLabel(String type) => switch (type) {
      'Short Text' => 'متن کوتاه',
      'Long Text' => 'متن بلند',
      'Number' => 'عدد',
      'Currency' => 'مبلغ',
      'Date' => 'تاریخ',
      'Choice' => 'انتخابی',
      'Checkbox' => 'بله / خیر',
      'Attachment' => 'فایل',
      'Multi Choice' => 'چندانتخابی',
      'User' => 'کاربر',
      'Department' => 'واحد سازمانی',
      'Item Table' => 'جدول اقلام',
      'Table' => 'جدول قابل‌تعریف',
      _ => type,
    };

String persianWorkflowStageTitle(String title) {
  final trimmed = title.trim();
  final lower = trimmed.replaceAll(RegExp(r'[-_]+'), ' ').toLowerCase();
  return switch (lower) {
    'start' => 'شروع',
    'user task' => 'وظیفه کاربر',
    'approval' => 'تأیید',
    'condition' => 'شرط',
    'system action' => 'اقدام خودکار',
    'wait' => 'انتظار',
    'end' => 'پایان',
    'start / user task' || 'start/user task' => 'شروع / وظیفه کاربر',
    _ => title,
  };
}

String persianServerMessage(String message) => switch (message.trim()) {
      'Workflow stages and transitions are not complete' =>
        'مراحل و مسیرهای گردش‌کار کامل نیستند.',
      _ => message,
    };

String persianNotificationTitle(String? title) {
  if (title == null || title.trim().isEmpty) return '';
  final trimmed = title.trim();

  final taskMatch = RegExp(r'^New workflow task:\s*(.+)$', caseSensitive: false)
      .firstMatch(trimmed);
  if (taskMatch != null) {
    final stage = taskMatch.group(1)?.trim() ?? '';
    return 'کار جدید در گردش‌کار: ${persianWorkflowStageTitle(stage)}';
  }

  final reqApprovedMatch =
      RegExp(r'^Workflow request approved(?::\s*(.+))?$', caseSensitive: false)
          .firstMatch(trimmed);
  if (reqApprovedMatch != null) {
    final rest = reqApprovedMatch.group(1)?.trim();
    return rest == null || rest.isEmpty
        ? 'درخواست گردش‌کار تأیید شد'
        : 'درخواست گردش‌کار تأیید شد: $rest';
  }

  final reqRejectedMatch =
      RegExp(r'^Workflow request rejected(?::\s*(.+))?$', caseSensitive: false)
          .firstMatch(trimmed);
  if (reqRejectedMatch != null) {
    final rest = reqRejectedMatch.group(1)?.trim();
    return rest == null || rest.isEmpty
        ? 'درخواست گردش‌کار رد شد'
        : 'درخواست گردش‌کار رد شد: $rest';
  }

  final reqReturnedMatch =
      RegExp(r'^Workflow request returned(?::\s*(.+))?$', caseSensitive: false)
          .firstMatch(trimmed);
  if (reqReturnedMatch != null) {
    final rest = reqReturnedMatch.group(1)?.trim();
    return rest == null || rest.isEmpty
        ? 'درخواست گردش‌کار بازگردانده شد'
        : 'درخواست گردش‌کار بازگردانده شد: $rest';
  }

  return trimmed;
}

String persianDocumentFieldLabel(String label) => switch (label.trim()) {
      'Company' => 'شرکت',
      'Workflow' => 'گردش‌کار',
      'Request Type' => 'نوع درخواست',
      'Subject' => 'موضوع',
      'Priority' => 'اولویت',
      'Status' => 'وضعیت',
      'Workflow Instance' => 'نمونه گردش‌کار',
      'Attachments' => 'پیوست‌ها',
      'Dynamic Values' => 'مقادیر متغیر',
      'Template Version' => 'نسخه الگو',
      'Status Key' => 'کلید وضعیت',
      'Search Text' => 'متن جستجو',
      _ => label,
    };

String persianDoctypeLabel(String doctype) => switch (doctype.trim()) {
      'ASOUD Workflow Request' => 'درخواست گردش‌کار',
      'Material Request' => 'درخواست کالا / خرید',
      'Leave Application' => 'درخواست مرخصی',
      'Job Applicant' => 'متقاضی استخدام',
      'Journal Entry' => 'سند حسابداری',
      'Payment Entry' => 'دریافت و پرداخت',
      'Sales Invoice' => 'فاکتور فروش',
      'Purchase Order' => 'سفارش خرید',
      _ => doctype,
    };
