# اجرای فرم‌ساز

قرارداد نسخهٔ ۲ افزایشی است. هر فیلد می‌تواند `help` داشته باشد و هر بخش می‌تواند `description`، `icon`، `color` یا `background_color` داشته باشد. بخش‌های `collapsible` با مقدار آغازین `collapsed` باز و بسته می‌شوند.

در فیلد `Select`، مقدار `style` برابر `dropdown` یا `radio` است. فیلد `Date` می‌تواند با `after_or_equal` به کلید یک فیلد تاریخ دیگر متصل شود و برای پیام سفارشی از `after_or_equal_message` استفاده کند.

جدول تکرارشونده با `required: true` یا `min_rows` هنگام اعتبارسنجی فرم حداقل ردیف‌ها را بررسی می‌کند. `default_source` در پیش‌نمایش، تا زمان دریافت مقدار سرور، با برچسب «دریافت خودکار» نمایش داده می‌شود و ذخیره نمی‌شود.

## Record sources (Link sources, fetch_from, not_equal, unique)

All keys are optional and additive; `schema_version` stays 2 and old forms render unchanged.

- **Sources** `Attendance`, `Shift Type`, `Training Event`, `Asset` (labels in `formSources`). Rows come from
  `forms.get_link_options` as `{name, label, extra}`; `meta.reason = 'no_employee'` shows
  «پرونده پرسنلی شما ثبت نشده است.». Scope is enforced by the server. Without a session these lists are not
  available and the picker says «این فهرست فقط با اتصال به سرور در دسترس است.» (no sample rows).
- `exclude_self: true` (Employee Link): sent as `exclude_self=1` to the options call; the server also rejects it on submit.
- `fetch_from: '<link key>.<attribute>'`: a read-only field filled from the chosen row's `extra` by
  `applyFieldChange` (`form_runtime/record_links.dart`). Date → ISO date, Time → time part of datetimes,
  other fields → Jalali text. Allowed attributes per source: `formFetchAttributes`; `schemaProblems` rejects others.
  The server recomputes the value on submit.
- **Dependent reset**: changing a field clears every Link whose `link_filter.value_field` is that field and every
  field fetched from a cleared link (transitively). Re-selecting the same value changes nothing.
- `not_equal` / `not_equal_message`: checked in `FormState.validate` when both fields are visible and non-empty.
- Table column `unique: true`: message «ردیف تکراری: {label}» from the table's validator.
- `default_source` `employee_number` and `default_shift` show «دریافت خودکار» until the server fills them.
