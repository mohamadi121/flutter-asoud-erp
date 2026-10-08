# Changelog

## 0.25.3+43

- After a successful organization login, the app clears the remembered offline demo choice so the next launch does not reopen the demo/offline dashboard by mistake.
- Keeps the editable login server address fix and latest `main` workflow/offline updates.
- Requires backend 0.14.0.

## 0.25.2+42

- Merged the latest `main` workflow/offline updates into the test release.
- Keeps the editable login server address fix from 0.25.1+41.
- Requires backend 0.14.0.

## 0.25.1+41

- Login server address is editable again. Entering an address without a scheme, such as `91.108.140.180:8080`, is normalized to `http://91.108.140.180:8080` before signing in.
- Requires backend 0.14.0.

## 0.25.0+40

- Purchase, supply and leave requests are system templates served by the backend: shared request form, list and detail pages (status tabs, search, filters, files with thumbnails, comments, edit and cancel), the leave form with a live preview and balance panel, and quick actions on the employee home.
- The offline preview shows the three templates with demo requests that follow the mockups; the old client-side leave and purchase demo types are gone.
- The offline leave preview follows the server's rounding and messages.
- Requires backend 0.14.0 (`docs/api/request_templates.md`, `docs/api/leave_request.md`).

## 0.24.1+39

- Existing offline databases now migrate to schema v2 by adding the retry columns (`attempts`, `next_attempt_at`), so queued writes and status updates keep working on devices that already had a v1 database.
- Requires backend 0.13.1.

## 0.24.0+38

- Offline preview now includes a richer demo app: office dashboard figures, request/cartable samples, workflow notifications, employee home, attendance, HR rows, parties, and three preset document templates.
- Unified personnel file preview into the four-tab page and seeded 12 realistic personnel files with documents, contracts, attendance, leave, salary visibility rules, and history.
- Added MyInfo, employee self-service home, demo transfer, restored login/demo choice/logout flows, and safer offline queue behavior with retry/backoff and ownership guards.
- Queued offline writes now cover roles, organization chart, purchase, attendance and generic requests, with a send-queue screen and rejected writes kept visible.
- Requires backend 0.13.0.

## 0.23.0+37

- Offline preview (no server): document templates, stage exit routes and requests are saved on the
  phone, so the new screens can be tried now. Request types come from the workflows designed on the
  phone plus a sample «درخواست خرید (نمونه آفلاین)»; items, users and departments use sample data.
  A submitted request gets a local number (LOCAL-…), a details page and print/PDF. Nothing saved in
  the preview is sent to a server.

## 0.22.0+36

- Request flow from the home «ثبت درخواست»: pick the request type, a redesigned form (request info,
  item table, attachments), a success page with the request summary, and request details with a
  three-dot menu: edit before approval, print, PDF export, view workflow, cancel. Print and PDF are
  generated in the app with a QR code.
- «ایجاد سند» (home) opens document templates: custom and ready templates and a four-step wizard
  (base info, fields, mapping each field to a fixed, request, user, company or system value,
  settings).
- Stage settings per type: «وظیفه کاربر» (stage form, responsible role or org unit, all members or
  one person), «تأیید / رد» (role picker with «مدیر مستقیم», decisions, exit route per decision) and
  «اقدام خودکار» (create a document from a template, change status, send a notification; success
  and error routes).
- Settings: «اشخاص و شرکت‌ها» became «گردش کار» and opens the workflow form, then the designer.
- Request type builder: step 3 now previews the built form instead of the workflow summary.
- Personnel file opens from data saved on the phone when the server is unreachable or older.
- Requires backend 0.12.0.

## 0.21.0+35

- Personnel file («پرونده پرسنلی») redesigned: compact header with the real employee code, summary
  cards (unit, manager, employment type, start date, current contract, document status), recent
  activity with clear titles, and Jalali dates everywhere.
- Personnel information sections: personal (with emergency contact and education), organizational
  (with direct manager), employment, contracts (with signed copy), salary and benefits, attendance and
  leave.
- Documents with category, number, expiry and validity status; history timeline (joining,
  promotions, contracts, salary changes).
- HR can add contracts, record promotions, and edit marital status, blood group, emergency contact,
  branch, direct manager, probation and contract dates.
- Employee panel: users who are only employees now land on their own home (greeting, date, quick
  actions, announcements) with خانه · کارتابل · درخواست‌ها · مکاتبات · بیشتر, «اطلاعات من», and
  check-in/out.
- Requires backend 0.11.0.

## 0.20.0+34

- Settings dashboard matches the design: compact status and quick-action cards, header with
  office selector, logo and notifications.
- Dates on the settings dashboard are Jalali (e.g. «پنجشنبه ۲ مهر ۱۴۰۵»), from a shared helper.
- «انواع درخواست» opens a request types list and a four-step builder: general info (name,
  short title, description, category, icon, status, visibility), request form (base fields,
  custom fields with ordering, field editor with technical name, default value, help text,
  required and options), workflow, and access roles.
- New request form field types: multi choice, user, department and item table (item, quantity,
  unit), with search pickers backed by ERPNext; builder default values are applied.
- Requires backend 0.10.0.

## 0.19.0+32

- Added per-stage deadlines, reminder timing, escalation roles, and optional reassignment.
- Added due and overdue states to workflow inbox cards.
- Added an hourly Frappe scheduler for one-time reminders and escalations.
- Added an overdue offline sample for serverless mobile validation.

## 0.18.0+31

- Added in-app workflow notifications and an unread badge.
- Added all/unread filters, read state, and navigation to workflow tracking.
- Added persistent offline notification previews for serverless mobile testing.
- Connected assignment, approval, rejection, completion, and correction events to Frappe notifications.

## 0.17.0+30

- Added separate received and sent workflow views with current-stage tracking.
- Added workflow instance details, assignees, document reference, and activity timeline.
- Added initiator assignment for reliable return-to-requester correction routes.
- Kept sent-request tracking available in the explicit offline preview mode.

## 0.13.0+19

- Added ASOUD-styled review and approval task details with read-only data from prior stages.
- Added mandatory return reasons, preserved correction data, and persistent offline return testing.
- Added safer multi-assignee rejection and return behavior with complete activity history.

## 0.12.0+18

- Added safe workflow conditions based on ERPNext document fields or prior form responses.
- Added explicit true/false branches to the mobile workflow designer.
- Added persistent offline routing for urgent and normal test scenarios, including condition history.
- Allowed startup to enter a clearly labelled local preview dashboard when ERPNext is unavailable.

## 0.11.0+17

- Added dynamic task forms, persistent on-device drafts, attachments, and local action history.
- Added explicit local-only state so offline actions are not mistaken for ERPNext success.
- Added server contracts for task details, drafts, final responses, attachments, and return-for-correction.

## 0.10.0+16

- Added role, department, and specific-employee assignment for workflow stages.
- Added the personal workflow inbox with guarded offline preview support.
- Connected task completion and rejection to the ASOUD workflow runtime API.

## 0.9.1 — Persistent initial setup

- Connected office creation, company accounting settings, and enabled office roles to ASOUD API v1.
- Added company-scoped setup recovery and startup routing to the first incomplete step.
- Added loading, API failure, retry, and duplicate-submit protection to the setup flow.

## 0.9.0 — Accounting reports

- Added live trial balance with opening, period, and closing columns.
- Added general and subsidiary ledger views with running balances.
- Added company, date, account, and optional party filters.
- Connected all reports to ERPNext GL Entry through ASOUD API v1.

## 0.8.1 — Analyzer hotfix

- Wrapped voucher row disposal in a block to satisfy Flutter lint rules.

## 0.8.0 — Double-entry accounting vouchers

- Added live voucher list and shared create/edit form.
- Added dynamic debit and credit rows with client-side balance validation.
- Added draft and submit-for-approval actions.
- Connected vouchers to the ASOUD ERPNext API.

## 0.7.1 — Analyzer hotfix

- Moved the account-detail mapping import before repository declarations.
- Restored compatibility with Dart analyzer and Flutter CI.

## 0.7.0 — Floating details and parties

- Added live floating-detail list and creation flow.
- Added shared individual/organization party form.
- Added multiple simultaneous party roles.
- Added Customer and Supplier synchronization with ERPNext.
- Added ledger-to-detail-group mapping screen.
- Added BLoC validation and repository tests.

## 0.6.0 — Live chart of accounts

- Connected the account tree to the ASOUD ERPNext API.
- Replaced sample parent choices with live ERPNext accounts.
- Added backend preview for the next available account code.
- Connected create and update forms to the repository.
- Added loading, empty, retry, saving, and API failure states.
- Kept floating details outside native ERPNext Account creation.

## 0.4.1 — Automatic account codes

- Clarified backend-generated codes for every account level.
- Account forms now describe pattern-based group/general/ledger/detail codes.

## 0.4.0 — Checkpoint 04

- Added one shared create/edit account form.
- Added parent validation for group/general/ledger/detail levels.
- Added automatic code generation switch.
- Added debit/credit/both account nature.
- Added in-page floating-detail guidance.
- Connected create and edit actions from the account tree.
- Added BLoC tests for account form validation.

## 0.3.0 — Checkpoint 03

- Fixed accrual accounting as the system basis.
- Added the main ERP dashboard with colored module icons.
- Kept route sales as an independent ERP module.
- Added the accounting module home.
- Added Iranian group/general/ledger/detail account hierarchy.
- Added an expandable chart-of-accounts screen.
- Added ERPNext Account repository mapping.
- Added chart-of-accounts BLoC tests.

## 0.2.0 — Checkpoint 02

- Added Iranian base accounting setup flow.
- Added selectable cash/accrual accounting basis.
- Added selectable rial/toman display unit.
- Added Persian fiscal-year start month.
- Added Iranian chart-of-accounts templates.
- Added initial role selection.
- Added reusable Frappe REST client.
- Added ERPNext Company model and repository.
- Added BLoC tests for base setup selections.

## 0.1.0 — Checkpoint 01

- Initialized Flutter feature-first architecture.
- Added BLoC office setup flow.
- Added personal/legal office selection and shared form.
# 0.5.1

- اصلاح `AsoudApiResponse.parse` به factory constructor سازگار با generic type در Dart

# 0.5.0

- افزودن parser استاندارد قرارداد API اختصاصی ASOUD
- افزودن متد `callAsoudMethod` برای بازکردن پاسخ‌های Frappe
- افزودن تست موفقیت و خطای قرارداد API
# 0.19.1+33

- داشبورد HR در نبود سرور با داده محلی یا حالت خالی قابل استفاده باز می‌شود.
- مدیریت اشخاص به فهرست قابل مشاهده و ویرایش تبدیل و پرسنل با HR یکپارچه شد.
- تنظیمات پایه به شش ماژول مرتبط تفکیک و کارت مستقل مدیریت اشخاص حذف شد.
- از ترکیب قالب پیش‌فرض سرفصل‌ها با کدینگ دستی جلوگیری شد.
- حذف امن سرفصل و نمایش پلکانی گروه، کل، معین و تفصیلی اضافه شد.
