# Changelog

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
