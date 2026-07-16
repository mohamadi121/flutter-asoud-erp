# ASOUD ERP Flutter

کلاینت موبایل ERP ایرانی مبتنی بر Flutter، BLoC و ERPNext/Frappe.

## وضعیت این checkpoint

- معماری Feature-first
- تم فارسی و RTL
- انتخاب نوع دفتر: حقیقی یا حقوقی
- فرم مشترک ایجاد/ویرایش دفتر
- اعتبارسنجی فرم با BLoC
- قرارداد Repository برای اتصال به Frappe API
- تنظیمات پایه حسابداری ایرانی با مبنای نقدی/تعهدی قابل انتخاب
- انتخاب ریال/تومان، ماه شروع سال مالی و الگوی کدینگ
- انتخاب نقش‌های اولیه
- Frappe REST client و پیاده‌سازی Company repository
- داشبورد اصلی با ماژول‌های حسابداری، خرید، فروش، انبار، دارایی ثابت، خزانه، فروش مویرگی و مکاتبات داخلی
- ساختار درختی سرفصل‌های گروه، کل، معین و تفصیلی
- اتصال آماده سرفصل‌ها به DocType حساب در ERPNext
- فرم مشترک ایجاد و ویرایش سرفصل با اعتبارسنجی BLoC
- تولید خودکار کد و راهنمای تفصیلی شناور داخل فرم

## اجرا

```bash
flutter pub get
flutter run
```

## تست

```bash
flutter analyze
flutter test
```

تنظیم اتصال سرور:

```bash
flutter run \
  --dart-define=ERPNEXT_BASE_URL=https://example.com \
  --dart-define=ERPNEXT_API_KEY=key \
  --dart-define=ERPNEXT_API_SECRET=secret
```

کلیدهای واقعی نباید داخل سورس یا GitHub ثبت شوند.
