# اجرای فرم‌ساز

قرارداد نسخهٔ ۲ افزایشی است. هر فیلد می‌تواند `help` داشته باشد و هر بخش می‌تواند `description`، `icon`، `color` یا `background_color` داشته باشد. بخش‌های `collapsible` با مقدار آغازین `collapsed` باز و بسته می‌شوند.

در فیلد `Select`، مقدار `style` برابر `dropdown` یا `radio` است. فیلد `Date` می‌تواند با `after_or_equal` به کلید یک فیلد تاریخ دیگر متصل شود و برای پیام سفارشی از `after_or_equal_message` استفاده کند.

جدول تکرارشونده با `required: true` یا `min_rows` هنگام اعتبارسنجی فرم حداقل ردیف‌ها را بررسی می‌کند. `default_source` در پیش‌نمایش، تا زمان دریافت مقدار سرور، با برچسب «دریافت خودکار» نمایش داده می‌شود و ذخیره نمی‌شود.


## Approval execution metadata

Request schemas may contain optional `execution: {kind}` and top-level fields
may contain `execution_key`. The editor reads the designer-only
`asoud_erp.api.v1.forms.execution_kinds` catalog (`success([{kind, label, parameters}])`).
Parameters are keyed objects with Persian `label`, allowed `types`, and `required`.
The endpoint is classified as a read and is never queued as an offline write.
No executor data is fabricated for preview; an unauthenticated catalog is empty.

The form-info sheet provides «اجرای پس از تأیید», its kind picker and parameter
mappings. Individual field settings provide the same mapping control. Workflow
step forms retain `execution_key` in their field model and offer the same picker
for compatible field types. Step mappings are partial overrides of the request
parameters; the last completed step wins on the server. Changing a form to
Document clears request execution metadata. The form runtime only collects
values as before; native writes occur on the backend after final approval.

Execution validation uses the catalog: unknown kinds and parameters, duplicate
mappings, incompatible types and missing required parameters have the same
Persian reasons as the backend. A catalog failure ends in an error and retry
control; a successful empty catalog explains that no execution kind is available.
Existing schemas and presets are unchanged.

The repository keeps the draft before loading the execution catalog. When an
authenticated catalog load fails because the network is unavailable, saving
returns the existing local-draft result, just like other form saves. Catalog
validation runs before the server write; permission and validation failures are
not treated as offline success.
