---
name: asoud-erp-expert
description: Domain expertise for ASOUD ERP in /home/soroush/Desktop/erp — the Persian (RTL) Flutter app `flutter-asoud-erp` and its Frappe/ERPNext/HRMS v15 extension app `frappe-erp-next-2` (`asoud_erp`). Use for any work on either repo — request types and the request flow, workflow designer/stage settings/system actions, document templates, personnel file and employee panel, HR, accounting/selling/stock/payroll/POS APIs, offline preview and sync, Jalali dates, tests on the local bench, CI, test releases (APK) and merging to main — and when the user reports "this screen doesn't work / I can't find X" in the app.
---

# ASOUD ERP expert

Two repos, one product (GitHub `mohamadi121/*`, the user pushes as `sush <soroushdeimi@gmail.com>`):

| Repo | Local main checkout | What it is |
|---|---|---|
| `flutter-asoud-erp` | `/home/soroush/Desktop/erp/flutter-asoud-erp` | Flutter app, Persian RTL UI, bloc/cubit, offline-first |
| `frappe-erp-next-2` | `/home/soroush/Desktop/erp/frappe-erp-next-2` | Frappe app `asoud_erp` on ERPNext + HRMS v15; thin `api/v1/*` modules |

Work happens in worktrees under `/home/soroush/Desktop/erp/.workers/` (`flutter`, `backend`,
`fwN` for workers). Users are Iranian companies: Persian text, Jalali dates, Persian digits.

Read `references/architecture.md` before changing code in either repo,
`references/gotchas.md` before diagnosing a report or touching offline/permissions,
and `references/workflow.md` before testing, delegating to workers, releasing or merging.

## Non-negotiable rules

- **Reuse ERPNext/HRMS; never reimplement or edit their source** (backend `AGENTS.md`).
  Wrap standard DocTypes and controller functions (mappers like `make_sales_invoice`,
  `get_payment_entry`, HRMS `get_leave_details`, POS page functions, query reports).
  No parallel ledger or JSON store duplicating transactions; presentation metadata is OK.
- **Thin API, pure services.** `api/v1/<module>.py` returns `success(data, meta)`;
  validation/logic that can be pure goes to `services/*.py` with pytest tests.
  Role checks with `erp_documents.require_roles` (`frappe.only_for` is a no-op in tests),
  company scope with `request_access.require_company`.
- **Every backend feature ships with**: integration test in `asoud_erp/integration_tests/`,
  doc in `docs/api/<module>.md` (+ link in `docs/api/README.md`), `CHANGELOG.md` entry,
  and the module added to the CI loop in `.github/workflows/erpnext-v15-integration.yml`.
- **Bank details never** go into `PERSONAL_FIELDS` or `update_personnel`; legacy
  FINANCIAL fields stay hidden from employees (tests enforce it).
- **Flutter**: every user-visible string is Persian; dates via `core/utils/jalali_date.dart`
  (`formatJalaliIso`, `toPersianDigits`); widgets from `core/widgets/asoud_ui.dart` /
  `asoud_form.dart`; must render at 320 px width without overflow (tests at 320 and 390).
- **Git**: user's identity only; never mention Claude/Anthropic/AI tools in commits, PRs,
  tags or code. Work on a feature branch; never push to `main` directly; merging into `main`
  goes through a PR the user merges (the harness blocks self-merging without review).

## Where things are (app, `lib/features/`)

| Feature | Key files |
|---|---|
| Home / settings | `dashboard/presentation/pages/dashboard_page.dart` (`_QuickActions`: «ثبت درخواست», «ایجاد سند»), `settings_dashboard_content.dart` («گردش کار», «انواع درخواست», ...) |
| Request types builder | `request_types/` (4 steps: اطلاعات کلی · فرم درخواست · پیش‌نمایش · دسترسی) |
| Requests | `workflows/presentation/pages/generic_request_page.dart` (list + form), `request_flow_pages.dart` (type sheet, success, details + ⋮ menu, print), `widgets/request_print.dart` (PDF), `widgets/request_link_fields.dart` |
| Workflow designer | `workflows/presentation/pages/workflow_designer_page.dart`, `stage_settings_page.dart` (user task / approval / system action), `workflow_stage_settings_page.dart` (condition/wait/end), `widgets/stage_pickers.dart` |
| Document templates | `workflows/presentation/pages/document_templates_page.dart`, `document_template_wizard_page.dart`, `create_document_settings_page.dart`; data `workflows/data/workflow_automation_repository.dart` |
| Offline preview data | `workflows/data/offline_preview_data.dart`, `repositories/preview_fallback_workflow_repository.dart` |
| HR / personnel file | `hr/presentation/pages/personnel_page.dart` (+ parts `personnel_file_page.dart`, `personnel_file_sections.dart`), `hr/data/personnel_file_repository.dart` |
| Employee panel | `employee/` (`EmployeeShell` for employee-only users) |

Backend `asoud_erp/api/v1/`: `workflow.py` (design, stage settings, `save_stage_routes`),
`workflow_runtime.py` (instances, tasks, System Actions), `workflow_request.py` (generic
requests: create/update/cancel), `document_templates.py`, `personnel_file.py`,
`hr_self_service.py`, `selling.py`, `payments.py`, `stock.py`, `buying.py`, `payroll.py`,
`pos.py`, `projects.py`, `financial_reports.py`, `support.py`, `dashboard.py`, `sync.py`.
