# Handoff: prompts, images and state (ASOUD ERP)

> این پوشه همه درخواست‌ها (پرامپت‌ها) و تصاویر طراحی که تا ۱۴۰۵/۰۷/۱۳ داده شده،
> نتیجه هر کدام، وضعیت فعلی پروژه و کارهای باقی‌مانده را دارد تا Claude بعدی کار را ادامه دهد.
> برای شروع یک جلسه جدید: این فایل، `prompts.md` و اسکیل `skill/asoud-erp-expert` را به Claude بدهید.

## Contents

| Path | What |
|---|---|
| [prompts.md](prompts.md) | Every user request, verbatim (Persian), in order, with its design images and the outcome |
| [images/](images/) | Design images and bug screenshots the user sent (`<prompt>-<n>.jpg/png`) |
| [skill/asoud-erp-expert/](skill/asoud-erp-expert/) | Claude Code skill for this project. Install: copy the folder to `~/.claude/skills/` |

## Repos and state (2026-10-05)

| Repo | `main` contains | Last test release |
|---|---|---|
| `mohamadi121/flutter-asoud-erp` (app) | Everything through app v0.23.0 (PR #16, squash-merged), plus a teammate's role management and organization chart work | v0.23.0 (debug APK, pre-release) |
| `mohamadi121/frappe-erp-next-2` (backend) | Everything through backend v0.12.0 (PR #12) | v0.12.0 (pre-release) |

The old feature branches (`feat/request-types`, `feat/backend-modules`) are fully merged.
Start new work from a fresh `origin/main` — a teammate (mohamadi121) also pushes to `main`.

### Done so far (by release)
- **App 0.20.0 / backend 0.10.0** — settings dashboard redesign, Jalali dates, 4-step request
  type builder with all field types (multi choice, user, department, item table); backend API
  modules on ERPNext/HRMS (dashboard, selling, sales pipeline, payments, stock, buying,
  HR self-service, payroll, projects, financial reports, POS, support) with docs and tests.
- **App 0.21.0 / backend 0.11.0** — personnel file (per the designs) and the employee panel.
- **App 0.22.0 / backend 0.12.0** — personnel file offline fallback; builder step 3 = form
  preview; settings «گردش کار»; home «ایجاد سند» (document templates list + wizard);
  stage settings per type (user task, approval with «مدیر مستقیم», automatic action);
  request flow (designed form → success → details with ⋮ edit/print/PDF/workflow/cancel);
  backend document templates, System Actions, exit routes, edit/cancel requests.
- **App 0.23.0** — offline preview (no server): templates, stage routes and requests saved on
  the phone (local numbers `LOCAL-…`, print/PDF), nothing sent to a server.

## Remaining work

### Open questions from prompt 15 (confirm with the user first)
1. ⋮ menu: implemented on the request **details** page; the user may also want it on the
   request **form**.
2. Home «ثبت درخواست» opens «درخواست‌های من» then «درخواست جدید»; the user may want the
   form to open directly.
3. Choosing «وظیفه کاربر» / «تأیید / رد» / «اقدام خودکار» in «افزودن مرحله» only adds the
   stage; the user may expect its settings page to open right away.
4. Only the home «منابع انسانی» became «ایجاد سند»; the settings page still has «منابع انسانی».

### Known gaps
- Automatic action «اجرای API» is shown as «به‌زودی» (not supported by design).
- Document types other than سند حسابداری (Journal Entry) and درخواست خرید کالا
  (Material Request) are «به‌زودی».
- «امکان ویرایش بعد از ارسال» is stored but not enforced.
- Releases are ~170 MB debug APKs; add a release build (`--split-per-abi`) and a signing keystore.

### MVP (agreed direction, backend ready — app screens needed)
1. Real figures on the home and settings dashboards (`dashboard` API).
2. Sales invoice and receive/pay screens (home buttons exist but do nothing): `selling`, `payments`.
3. Employee request cards wired to the real processes: leave, mission, advance, IT
   (`hr_self_service`, `support`).
4. Reports: AR/AP aging and profit & loss (`financial_reports`).

After MVP: full stock and buying, payroll, projects and timesheets, POS, balance sheet.
Before a final release: deploy the backend to the real server (`bench --site <site> migrate`),
HRMS setup per company (holiday list, leave approvers, payroll/advance accounts), signed release APK.

## How to continue (for Claude)
- Load the `asoud-erp-expert` skill; it has the architecture, gotchas, local bench/test
  commands, release and merge steps.
- Never mention Claude/AI in commits or PRs; commit as the user; open PRs to `main` and let
  the user merge.
- Answer the user in Persian; they review on a phone, often in the offline preview.
