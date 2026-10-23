import 'package:flutter/material.dart';

/// Presentation metadata for the request picker. Server request types remain
/// the source of truth; this only adds stable module, subgroup and search
/// information to types that are available to the current user.
class NewRequestMetadata {
  const NewRequestMetadata({
    required this.title,
    required this.module,
    required this.subgroup,
    required this.keywords,
    this.description = '',
    this.offlineForm = false,
  });

  final String title;
  final String module;
  final String subgroup;
  final List<String> keywords;
  final String description;

  /// True when the purchase system template is the right form for this row.
  final bool offlineForm;
}

const purchaseRequestBank = <NewRequestMetadata>[
  NewRequestMetadata(
      title: 'درخواست خرید کالا',
      module: 'خرید',
      subgroup: 'تأمین و خرید',
      keywords: ['کالا', 'خرید'],
      description: 'تأمین کالای مورد نیاز واحد از طریق خرید',
      offlineForm: true),
  NewRequestMetadata(
      title: 'درخواست خرید خدمات',
      module: 'خرید',
      subgroup: 'تأمین و خرید',
      keywords: ['خدمات', 'خرید'],
      description: 'تأمین خدمات مورد نیاز از بیرون سازمان',
      offlineForm: true),
  NewRequestMetadata(
      title: 'درخواست خرید فوری',
      module: 'خرید',
      subgroup: 'تأمین و خرید',
      keywords: ['فوری', 'خرید'],
      description: 'خرید کالا یا خدمات با نیاز زمانی نزدیک',
      offlineForm: true),
  NewRequestMetadata(
      title: 'درخواست استعلام قیمت',
      module: 'خرید',
      subgroup: 'تأمین و خرید',
      keywords: ['استعلام', 'قیمت'],
      description: 'دریافت قیمت کالا یا خدمات از تأمین‌کنندگان'),
  NewRequestMetadata(
      title: 'درخواست دریافت پیش‌فاکتور',
      module: 'خرید',
      subgroup: 'تأمین و خرید',
      keywords: ['پیش‌فاکتور', 'قیمت'],
      description: 'درخواست پیش‌فاکتور از تأمین‌کننده'),
  NewRequestMetadata(
      title: 'درخواست ثبت سفارش خرید',
      module: 'خرید',
      subgroup: 'سفارش‌ها',
      keywords: ['ثبت', 'سفارش'],
      description: 'ثبت سفارش خرید برای تأمین‌کننده'),
  NewRequestMetadata(
      title: 'درخواست اصلاح سفارش خرید',
      module: 'خرید',
      subgroup: 'سفارش‌ها',
      keywords: ['اصلاح', 'سفارش'],
      description: 'اصلاح مشخصات سفارش خرید ثبت‌شده'),
  NewRequestMetadata(
      title: 'درخواست لغو سفارش خرید',
      module: 'خرید',
      subgroup: 'سفارش‌ها',
      keywords: ['لغو', 'سفارش'],
      description: 'لغو سفارش خرید ثبت‌شده'),
  NewRequestMetadata(
      title: 'درخواست معرفی تأمین‌کننده',
      module: 'خرید',
      subgroup: 'تأمین‌کنندگان',
      keywords: ['معرفی', 'تأمین‌کننده'],
      description: 'معرفی تأمین‌کننده جدید برای همکاری'),
  NewRequestMetadata(
      title: 'درخواست ارزیابی تأمین‌کننده',
      module: 'خرید',
      subgroup: 'تأمین‌کنندگان',
      keywords: ['ارزیابی', 'تأمین‌کننده'],
      description: 'ارزیابی عملکرد یک تأمین‌کننده'),
  NewRequestMetadata(
      title: 'درخواست قرارداد خرید',
      module: 'خرید',
      subgroup: 'قراردادها',
      keywords: ['قرارداد', 'خرید'],
      description: 'تنظیم یا ثبت قرارداد خرید'),
  NewRequestMetadata(
      title: 'درخواست مرجوعی خرید',
      module: 'خرید',
      subgroup: 'مرجوعی',
      keywords: ['مرجوعی', 'خرید'],
      description: 'برگشت کالای خریداری‌شده به تأمین‌کننده'),
];

const hrRequestBank = <NewRequestMetadata>[
  NewRequestMetadata(
      title: 'درخواست مرخصی',
      module: 'منابع انسانی',
      subgroup: 'مرخصی و مأموریت',
      keywords: ['مرخصی'],
      description: 'ثبت مرخصی استحقاقی، استعلاجی یا ساعتی'),
  NewRequestMetadata(
      title: 'درخواست مأموریت',
      module: 'منابع انسانی',
      subgroup: 'مرخصی و مأموریت',
      keywords: ['مأموریت'],
      description: 'ثبت مأموریت کاری داخل یا خارج از شهر'),
  NewRequestMetadata(
      title: 'درخواست اضافه‌کاری',
      module: 'منابع انسانی',
      subgroup: 'حضور و غیاب',
      keywords: ['اضافه‌کاری'],
      description: 'ثبت ساعت‌های اضافه‌کاری انجام‌شده'),
  NewRequestMetadata(
      title: 'درخواست اصلاح تردد',
      module: 'منابع انسانی',
      subgroup: 'حضور و غیاب',
      keywords: ['تردد', 'ورود', 'خروج'],
      description: 'اصلاح ورود یا خروج ثبت‌نشده یا نادرست'),
  NewRequestMetadata(
      title: 'درخواست تغییر شیفت',
      module: 'منابع انسانی',
      subgroup: 'حضور و غیاب',
      keywords: ['شیفت'],
      description: 'درخواست تغییر شیفت کاری'),
  NewRequestMetadata(
      title: 'درخواست مساعده',
      module: 'منابع انسانی',
      subgroup: 'مالی پرسنلی',
      keywords: ['مساعده', 'حقوق'],
      description: 'درخواست مساعده از حقوق'),
  NewRequestMetadata(
      title: 'درخواست تسویه‌حساب پرسنل',
      module: 'منابع انسانی',
      subgroup: 'مالی پرسنلی',
      keywords: ['تسویه', 'پرسنل'],
      description: 'آغاز بررسی تسویه‌حساب پرسنل'),
  NewRequestMetadata(
      title: 'درخواست گواهی اشتغال به کار',
      module: 'منابع انسانی',
      subgroup: 'گواهی و مدارک',
      keywords: ['گواهی', 'اشتغال'],
      description: 'دریافت گواهی اشتغال به کار'),
  NewRequestMetadata(
      title: 'درخواست آموزش کارکنان',
      module: 'منابع انسانی',
      subgroup: 'آموزش و تجهیزات',
      keywords: ['آموزش'],
      description: 'ثبت نیاز آموزشی کارکنان'),
  NewRequestMetadata(
      title: 'درخواست تحویل یا عودت تجهیزات',
      module: 'منابع انسانی',
      subgroup: 'آموزش و تجهیزات',
      keywords: ['تجهیزات', 'تحویل', 'عودت'],
      description: 'تحویل یا بازگرداندن تجهیزات سازمانی'),
];

NewRequestMetadata? _bankRow(String title) => [
      ...purchaseRequestBank,
      ...hrRequestBank
    ].where((row) => row.title == title).firstOrNull;

const _moduleLabels = <String, String>{
  'HR': 'منابع انسانی',
  'Human Resources': 'منابع انسانی',
  'Accounts': 'مالی',
  'Accounting': 'مالی',
  'Finance': 'مالی',
  'Purchase': 'خرید',
  'Buying': 'خرید',
  'Stock': 'انبار',
  'Inventory': 'انبار',
  'Selling': 'فروش',
  'Sales': 'فروش',
  'IT': 'فناوری اطلاعات',
  'Information Technology': 'فناوری اطلاعات',
};

String requestModule(Map<String, dynamic> type) {
  final title = '${type['workflow_title'] ?? ''}';
  final bank = _bankRow(title);
  if (bank != null) return bank.module;
  return _moduleLabels[
          '${type['module'] ?? type['module_key'] ?? type['request_category'] ?? ''}'] ??
      'سایر';
}

String requestSubgroup(Map<String, dynamic> type) {
  final title = '${type['workflow_title'] ?? ''}';
  final bank = _bankRow(title);
  if (bank != null) return bank.subgroup;
  final subgroup = '${type['request_subgroup'] ?? ''}';
  return subgroupsForModule(requestModule(type)).contains(subgroup)
      ? subgroup
      : 'سایر';
}

List<String> requestKeywords(Map<String, dynamic> type) {
  final title = '${type['workflow_title'] ?? ''}';
  final bank = _bankRow(title);
  return [
    ...bank?.keywords ?? const [],
    ...((type['keywords'] as List?) ?? const []).map((e) => '$e')
  ];
}

bool requestTypeIsVisible(Map<String, dynamic> type) {
  final active = type['active'] ?? type['is_active'] ?? type['enabled'];
  final published = type['published'] ?? type['is_published'];
  final allowed = type['can_submit'] ??
      type['user_submittable'] ??
      type['allow_user_submission'];
  final version = type['template_version'] ?? type['published_version'];
  return active != false &&
      published != false &&
      allowed != false &&
      (version == null || version is num && version > 0);
}

List<Map<String, dynamic>> filterNewRequestTypes(
  Iterable<Map<String, dynamic>> types, {
  String module = 'همه',
  String subgroup = 'همه درخواست‌ها',
  String query = '',
}) {
  final needle = query.trim().toLowerCase();
  return [
    for (final type in types)
      if (requestTypeIsVisible(type) &&
          (module == 'همه' || requestModule(type) == module) &&
          (subgroup == 'همه درخواست‌ها' || requestSubgroup(type) == subgroup) &&
          (needle.isEmpty ||
              ('${type['workflow_title'] ?? ''} ${type['short_title'] ?? ''} ${type['process_description'] ?? ''} ${requestKeywords(type).join(' ')}')
                  .toLowerCase()
                  .contains(needle)))
        type,
  ];
}

const newRequestModules = <({String title, IconData icon, Color color})>[
  (title: 'همه', icon: Icons.apps_rounded, color: Color(0xFF1769F6)),
  (
    title: 'منابع انسانی',
    icon: Icons.people_alt_outlined,
    color: Color(0xFF2E7D32)
  ),
  (
    title: 'مالی',
    icon: Icons.account_balance_wallet_outlined,
    color: Color(0xFFEF8C22)
  ),
  (title: 'خرید', icon: Icons.shopping_cart_outlined, color: Color(0xFF2697D5)),
  (title: 'انبار', icon: Icons.inventory_2_outlined, color: Color(0xFF7E57C2)),
  (title: 'فروش', icon: Icons.point_of_sale_outlined, color: Color(0xFFD64D86)),
  (
    title: 'فناوری اطلاعات',
    icon: Icons.memory_outlined,
    color: Color(0xFF009688)
  ),
  (title: 'سایر', icon: Icons.more_horiz_rounded, color: Color(0xFF718096)),
];

const _otherSubgroup = 'سایر';

List<String> subgroupsForModule(String module) => [
      'همه درخواست‌ها',
      ...switch (module) {
        'خرید' => const [
            'تأمین و خرید',
            'سفارش‌ها',
            'تأمین‌کنندگان',
            'قراردادها',
            'مرجوعی'
          ],
        'منابع انسانی' => const [
            'مرخصی و مأموریت',
            'حضور و غیاب',
            'مالی پرسنلی',
            'گواهی و مدارک',
            'آموزش و تجهیزات'
          ],
        'مالی' => const [
            'پرداخت و دریافت',
            'هزینه‌ها',
            'اسناد و گزارش‌ها'
          ],
        'انبار' => const [
            'ورود و خروج کالا',
            'انبارگردانی',
            'انتقال بین انبارها'
          ],
        'فروش' => const [
            'مشتریان',
            'پیش‌فاکتور و سفارش',
            'قرارداد و مرجوعی'
          ],
        'فناوری اطلاعات' => const [
            'دسترسی و حساب کاربری',
            'پشتیبانی و تجهیزات',
            'نرم‌افزار و سامانه‌ها'
          ],
        _ => const <String>[],
      },
      if (module != 'همه') _otherSubgroup,
    ];
