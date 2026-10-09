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

String persianRoleLabel(String role) => erpNextRoleLabels[role] ?? role;

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

String persianWorkflowStageTitle(String title) => switch (title.trim()) {
      'Start' => 'شروع',
      'User Task' => 'وظیفه کاربر',
      'Approval' => 'تأیید',
      'Condition' => 'شرط',
      'System Action' => 'اقدام خودکار',
      'Wait' => 'انتظار',
      'End' => 'پایان',
      _ => title,
    };

String persianServerMessage(String message) => switch (message.trim()) {
      'Workflow stages and transitions are not complete' =>
        'مراحل و مسیرهای گردش‌کار کامل نیستند.',
      _ => message,
    };
