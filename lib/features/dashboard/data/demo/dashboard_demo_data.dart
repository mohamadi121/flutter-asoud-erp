/// Demo numbers for the office dashboard and the settings dashboard in the
/// offline preview (no session): «شرکت نمونه آسود».
/// Served only in preview; a real session always reads the server.
library;

/// One dashboard metric card: title, value and the line under it.
class DemoMetric {
  const DemoMetric(this.title, this.value, this.hint);
  final String title;
  final String value;
  final String hint;
}

/// Figures on the home dashboard while previewing.
List<DemoMetric> demoDashboardMetrics() => const [
      DemoMetric('دریافتی امروز', '۱۲٬۴۵۰٬۰۰۰ ریال', '۳ دریافت امروز'),
      DemoMetric('فروش امروز', '۸٬۲۰۰٬۰۰۰ ریال', '۲ فاکتور فروش'),
      DemoMetric('موجودی بانک', '۴۵۶٬۷۰۰٬۰۰۰ ریال', '۲ حساب بانکی'),
      DemoMetric('اسناد باز', '۶ سند', '۳ درخواست · ۳ سند حسابداری'),
    ];

/// Value shown on a settings «خلاصه وضعیت سیستم» card while previewing.
String demoSystemStatus(String title) => switch (title) {
      'کاربران فعال' => '۱۴',
      'کاربران آنلاین' => '۳',
      'فضای ذخیره‌سازی' => '۶۸٪',
      'درخواست‌های در انتظار' => '۶',
      'خطاهای سیستم' => '۰',
      'وضعیت همگام‌سازی' => 'موقت',
      _ => '—',
    };
