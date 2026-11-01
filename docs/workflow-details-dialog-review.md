# فایل‌های تغییرکرده در اصلاح پنجرهٔ جزئیات گردش‌کار

این فهرست فقط مربوط به درخواست پنجرهٔ جزئیات است؛ تغییرات موجودِ درخواست قبلی حفظ شده‌اند.

## فرانت‌اند

- `lib/features/workflows/presentation/widgets/workflow_details_dialog.dart`
- `lib/features/workflows/presentation/pages/workflow_list_page.dart`
- `lib/features/workflows/domain/entities/workflow_definition.dart`
- `lib/features/workflows/data/repositories/frappe_workflow_repository.dart`
- `test/features/workflows/workflow_details_dialog_test.dart`
- `test/features/workflows/workflow_card_actions_test.dart` — سازگاری پاسخ آزمایشیِ بارگذاری جزئیات
- `test/ui/workflow_list_page_test.dart` — انتظار عمدیِ «مشاهده مراحل» برای گردش فعال و بررسی بازشدن همان تعریف
- `CHANGELOG.md`
- `docs/workflow-details-dialog-review.md`

## بک‌اند

- `asoud_erp/api/v1/workflow.py` — خروجی خواندنیِ تکمیلی در API طراحی موجود
- `asoud_erp/services/workflow_contract.py` — استفادهٔ مشترک از همان بررسی‌های مراحل/مسیرها، بدون تغییر قواعد فعال‌سازی
- `asoud_erp/tests/test_workflow_details_summary.py`
- `asoud_erp/integration_tests/test_workflow_card_actions.py`
- `e2e/tests/workflow-card-actions.spec.ts`
- `docs/api/workflow-card-actions.md`
- `CHANGELOG.md`

## نتیجهٔ آزمون پنجره

- فعال: موفق؛ نشان سبز، نسخه/کد/درخواست واقعی، مراحل و مسیرهای کامل، دکمهٔ «مشاهده مراحل» و بدون هشدار ساختگی.
- غیرفعال: موفق؛ نشان خاکستری و «مشاهده مراحل»، بدون نمایش اشتباهِ نقص از خلاصهٔ قدیمی.
- نیازمند تکمیل: موفق؛ نشان هشدار، نقص‌های فارسیِ حاصل از بررسی طرح ذخیره‌شده و دکمهٔ «طراحی مراحل».
- ۱۹ آزمون اختصاصی پنجره با فونت و آیکن واقعی، در RTL و عرض‌های ۳۲۰، ۳۹۰ و ۴۳۰ موفق‌اند. شامل مسیر کامل/مرحله ناقص، خلاصهٔ قدیمی، حفظ وضعیت فعال قدیمی، سند حسابداری، شکست دریافت/تلاش دوباره، سرور قدیمی، بستن و نبود عملیات حذف/تغییر وضعیت در پنجره.
- ۲۷ آزمون پنجره و صفحهٔ فهرست موفق‌اند؛ بازشدن همان تعریف در صفحهٔ موجود مراحل نیز بررسی شد.
- ۳۸۰ آزمون رگرسیون مرتبط گردش‌کار موفق‌اند.
- تحلیل ایستای Dart: بدون مورد. بررسی `git diff --check`: موفق.
- بک‌اند: ۱۳۰۰ آزمون سبک و `ruff check .` موفق‌اند؛ سه آزمون جدید، استقلال وضعیت مراحل/مسیرها و خواندنی‌بودن محاسبه را بررسی می‌کنند.
- رندر فعال، غیرفعال و نیازمند تکمیل با فونت Vazirmatn و آیکن واقعی بازبینی شد؛ تصاویر آزمایشی در `build/workflow-details-*.png` تولید می‌شوند و فایل اجرایی/دادهٔ نمونهٔ برنامه نیستند.

آزمون پایگاه داده و HTTP واقعی اجرا نشده است؛ محیط محلی Frappe/Bench ندارد. پاسخ API در آزمون پنجره شبیه‌سازی شده، اما در برنامه اطلاعات از API طراحی موجود و گزارش بررسی طرح ذخیره‌شده دریافت می‌شود. هیچ اطلاعات تاریخی، مجوز، وضعیت ذخیره‌شده یا قاعدهٔ اجرای گردش‌کار توسط نمایش جزئیات تغییر نمی‌کند.
