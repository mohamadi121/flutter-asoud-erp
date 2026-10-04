# Architecture

## Backend (`asoud_erp`)

- `api/v1/*.py` whitelisted methods → `responses.success(data, meta)` envelope
  (`{"ok": true, "data": ..., "meta": {"api_version": "v1"}}` inside Frappe's `message`).
  Errors are `frappe.throw` (417 ValidationError, 403 PermissionError).
- `services/*.py` pure logic (no frappe import where possible) tested with plain pytest
  in `asoud_erp/tests/`. Examples: `workflow_stage_policy.normalize_stage_config`,
  `document_templates` (catalog, `normalize_template`, `resolve_values`, `build_document`,
  `PRESETS`), `personnel_file` helpers, `transaction_lines`, `financial_reports`.
- `services/erp_documents.py`: `require_roles`, `load`, `submit`, `cancel`, `insert`,
  `date_range`, `list_meta`. `services/request_access.py`: company access,
  `request_permission` (owner, System/HR Manager, or a stage assignee of the instance).
- Doctypes live in `asoud_erp/asoud_erp/doctype/` (ASOUD Workflow Definition/Stage/
  Transition/Instance/Task/Activity/Request, ASOUD Document Template, ASOUD Personnel
  Record, ...). After adding fields: `bench --site <site> migrate`.

### Workflow engine
- Definition → stages (`Start`, `User Task`, `Approval`, `Condition`, `System Action`,
  `Wait`, `End`) + transitions (`condition_json.action` = Approve/Reject/Return/Complete/
  Success/Error, Persian `transition_label`).
- Request form = the User Task right after Start (`workflow_request._form_stage`).
  `create_request` starts the instance and completes the requester's own form task.
- Assignments: Role, Department, Employee, Initiator, Initiator Department, Direct Manager
  (Employee `reports_to`).
- `_next_stage`: label/action match; only forward decisions (Complete/Approve) fall back
  to a single unlabeled route — a Reject with no route ends the instance as Rejected.
- System Action (`_run_system_action`): Create Document (template → ERPNext Journal Entry
  or Material Request, draft or submitted), Change Status (`display_status` on the
  request), Send Notification. Runs in a savepoint; failure → rollback, `System Action
  Failed` activity, Error route or instance `Failed` + notify System Managers.
  External API calls are deliberately not supported.
- Docs: `docs/workflow-runtime-v1.md`, `docs/api/document_templates.md`.

## App (Flutter)

- State: bloc/cubit; repositories per feature; `FrappeApiClient.callAsoudMethod` unwraps
  the envelope. Methods whose last segment starts with `current_`, `get_`, `list_`,
  `preview_` or ends with `_options`/`_fields` are reads; everything else is a **queued
  mutation** (OfflineMutationStore) when the network fails.
- `AppConfig.offlineDemoMode` defaults to **true**: without a restored session the splash
  opens `DashboardLandingPage(offlinePreview: true)`. In this preview (`!client.isAuthenticated`):
  - workflows: `PreviewFallbackWorkflowRepository` keeps designs in SharedPreferences
    `asoud_workflow_designs_v2`; `saveStageRoutesLocally` for exit routes;
  - document templates: `WorkflowAutomationRepository.isLocal` → SharedPreferences
    `asoud_document_templates_local_v1`, presets/options mirrored in `offline_preview_data.dart`;
  - requests: `GenericRequestRepository.isLocal` → types from local designs + sample
    «درخواست خرید (نمونه آفلاین)», sample masters, outbox rows with status `localOnly`
    (never synced), local number `LOCAL-…`, details and print/PDF work.
  - personnel file falls back to `PersonnelRepository.detail` (cache/local/demo) when the
    file API is unreachable or 404.
- Employee-only users (`employee/domain/employee_mode.dart isEmployeeOnly`) land in
  `EmployeeShell`, not the manager dashboard — manager quick actions are not visible there.
- Print/PDF: packages `pdf` + `printing`; fonts Vazirmatn from `assets/fonts/`; PDF text
  must replace ZWNJ (U+200C) — the PDF font has no glyph (see `_p` in `request_print.dart`).
