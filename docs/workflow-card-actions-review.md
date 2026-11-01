# بررسی محدود منوی کارت گردش‌کار

## علت

- گزینهٔ فعال‌سازی در `onSelected` هیچ شاخهٔ اجرایی نداشت و همیشه همان عنوان ثابت را نشان می‌داد.
- حذف در منو وجود نداشت؛ پاسخ فهرست نیز نشانگر سیستمی/مجوز حذف را نمی‌فرستاد.
- فعال‌سازی سرور فقط آمادگی ذخیره‌شده و یک اتصال قدیمیِ اجباری را بررسی می‌کرد؛ تکمیل طراحی آمادگی را تازه نمی‌کرد. موتور موجود، گراف ذخیره‌شده را خودش اجرا می‌کند و برای آن طراحی به اتصال جداگانه نیاز ندارد.

## اصلاح محدود

همان API تغییر وضعیت و حذف استاندارد استفاده می‌شوند. منو بر اساس وضعیت واقعی تغییر می‌کند؛ حذف فقط با مجوز سرور و برای گردش‌کار غیرسیستمی دیده می‌شود و تأیید لازم دارد. تغییرات منتظر پاسخ موفق سرور می‌مانند، دوبار اجرا نمی‌شوند و جستجو/فیلتر/مرتب‌سازی جاری پس از موفقیت تازه می‌شود. خطا دلیل فارسی دارد؛ رنگ، ابعاد و چیدمان کارت‌ها دست‌نخورده است.

سرور تنظیمات و مسیرهای ذخیره‌شده را هنگام فعال‌سازی اعتبارسنجی می‌کند. غیرفعال‌سازی اجراهای قبلی را حذف یا متوقف نمی‌کند. حذف دارای محافظت مجوز/دفتر، نشانگرهای سیستمی، درخواست، اجرا، نسخه‌های تاریخی، وابستگی فرم و مرحله و کنترل پیوند استاندارد است. حذف تنها گراف فنی بدون وابستگی را در همان تراکنش پاک می‌کند؛ حذف اجباری استفاده نمی‌شود. وجود تاریخچهٔ ویرایش نیز محافظه‌کارانه مانع حذف است.

## آزمون واقعی اجراشده

- `flutter test --no-pub test/features/workflows/workflow_card_actions_test.dart test/features/workflows/workflow_list_cubit_test.dart test/ui/layout_bottom_padding_test.dart`: **۳۰ موفق**؛ RTL در عرض‌های ۳۲۰، ۳۹۰، ۴۳۰. شامل تأیید/انصراف حذف، حذف نامجاز، گردش‌کار ناقص، فعال و غیرفعال‌سازی، بارگذاری مجدد، خطای سرور، تغییر فیلتر هنگام ذخیره و جلوگیری از بازگشت کارت حذف‌شده از پیش‌نمایش قدیمی. ارتباط در این آزمون با پاسخ‌های قراردادی شبیه‌سازی می‌شود، نه سرور مستقر.
- `dart analyze --fatal-infos --fatal-warnings`: بدون مورد.
- بک‌اند `python -X utf8 -m pytest -q`: **۱۲۹۷ موفق**. UTF-8 برای خواندن fixtureهای فارسی ویندوز لازم است.
- `ruff check .` و `git diff --check`: موفق.
- مجموعهٔ کلی Flutter نیز اجرا شد ولی سبز نیست: شکست‌های ترتیب/قفل فایل در آزمون‌های صف آفلاین و یک مقایسهٔ تصویری صفحهٔ درخواست جدید مشاهده شد. تغییرات این بخش‌ها خارج از دامنه است و انجام نشد.
- دو نمونه روی نسخهٔ دست‌نخوردهٔ `df4414c` در worktree جداگانه نیز تکرار شدند: ترتیب صف مالک در `offline_sync_owner_scope_test.dart` و تفاوت تصویری ۳٫۹۷٪ در `new_request_sheet_golden_test.dart`.

## موارد اجرا‌نشده

Frappe و Bench در محیط محلی نصب نیستند. آزمون‌های پایگاه داده و HTTP نوشته و در CI ثبت شده‌اند، اما نتیجهٔ اجرای واقعی آن‌ها هنوز تأیید نشده است. هیچ دفتر، گردش‌کار یا دادهٔ واقعی سرور در این بررسی حذف نشد. این تغییر نیازمند استقرار جفت فرانت/بک‌اند است؛ فیلد، مهاجرت، API یا موتور موازی ندارد.

## فایل‌ها

فرانت:

- `lib/features/workflows/presentation/pages/workflow_list_page.dart`
- `lib/features/workflows/presentation/cubit/workflow_list_cubit.dart`
- `lib/features/workflows/data/workflow_card_repository.dart`
- `lib/features/workflows/data/repositories/frappe_workflow_repository.dart`
- `lib/features/workflows/domain/entities/workflow_definition.dart`
- `lib/app/app.dart` — فقط تزریق repository عملیات کارت
- `test/features/workflows/workflow_card_actions_test.dart`
- `test/features/workflows/workflow_list_cubit_test.dart`
- `CHANGELOG.md` و همین گزارش

بک‌اند:

- `asoud_erp/api/v1/workflow.py`
- `asoud_erp/api/v1/workflow_runtime.py` — فقط قفل تعریف هنگام شروع برای هماهنگی با حذف/وضعیت
- `asoud_erp/asoud_erp/doctype/asoud_workflow_definition/asoud_workflow_definition.py`
- `asoud_erp/services/workflow_contract.py`
- `asoud_erp/services/workflow_lifecycle.py`
- `asoud_erp/tests/test_workflow_card_policy.py`
- `asoud_erp/integration_tests/test_workflow_card_actions.py`
- `e2e/tests/workflow-card-actions.spec.ts`
- `e2e/tests/workflow-submission-source.spec.ts` و `e2e/support/py/site_prep.py` — صرفاً سازگاری پاک‌سازی fixture آزمایشی با محافظت جدید تاریخچه؛ مسیر عملیاتی استثنا ندارد
- `.github/workflows/erpnext-v15-integration.yml` و `e2e/package.json` — ثبت آزمون‌ها
- `docs/api/workflow-card-actions.md`، `docs/api/README.md` و `CHANGELOG.md`

رفتار حذف استاندارد و پاک‌سازی تاریخچه با کد رسمی [حذف سند در نسخهٔ ۱۵](https://github.com/frappe/frappe/blob/version-15/frappe/model/delete_doc.py) مقایسه شد؛ به همین دلیل نسخه‌های تاریخی مانع حذف شده‌اند.
