# Condition / If-Else v2 — implementation and verification

## Scope

Existing stage settings route, workflow repository, designer, native transitions,
JSON settings and runtime are extended together. No replacement engine, new
business table or parallel API. Existing single-predicate settings retain their
runtime semantics; migrating a complete old stage requires explicit confirmation.

## Implemented

- Independent stable rule IDs; remove the selected row; 1–50 resource-bounded
  rules. All/Any appears only with multiple rules.
- Real pinned source schema / native fields, guaranteed prior task outputs, real
  instance fields; changing source clears incompatible values. No future or
  optional-branch output is offered as a guaranteed source.
- Type-aware predicates; exact decimal comparison, inclusive number/date ranges,
  real Select options/labels, Jalali picker and Persian summaries. Invalid dates
  and reversed ranges are rejected. Empty operators omit stale values.
- Fixed True/False exits; destinations remain in the existing Canvas connection
  editor. Existing transition IDs survive changing the target; disconnect removes
  only the selected connection. Diamond fill #FFF3DE and outline #BA8427.
- Server evaluates every rule, then selects one existing boolean transition.
  Missing prior output, stale metadata and invalid values raise instead of silently
  becoming False. Active/running v2 definitions cannot be redesigned in place.
- The settings check is explicitly structural, not a simulated runtime execution.
  Saving settings never publishes the workflow or creates a request/task.

## Files for this change

- `lib/features/workflows/presentation/pages/workflow_condition_settings.dart`
- `lib/features/workflows/presentation/pages/workflow_stage_settings_page.dart`
- `lib/features/workflows/presentation/pages/workflow_designer_page.dart`
- `lib/features/workflows/presentation/cubit/workflow_designer_cubit.dart`
- `lib/features/workflows/presentation/widgets/workflow_graph_canvas.dart`
- `lib/features/workflows/presentation/widgets/workflow_graph_geometry.dart`
- `lib/features/workflows/domain/entities/workflow_definition.dart`
- `lib/features/workflows/data/repositories/frappe_workflow_repository.dart`
- `test/features/workflows/condition_settings_test.dart`
- `test/features/workflows/workflow_graph_geometry_test.dart`
- `integration_test/workflow_condition_test.dart`
- `CHANGELOG.md`

Backend counterpart: `docs/api/workflow-condition.md`, existing workflow API,
runtime, lifecycle and stage policy; condition service + binding adapter; pure,
native integration and HTTP tests registered in existing CI.

## Verified locally

- `flutter analyze --no-pub`: zero issues.
- Workflow suite plus existing stage form UI suite: **501 passed**.
- Final focused condition UI suite after visual adjustments: **11 passed**.
- Layout widgets at 320/390/430 px; a 390 px RTL real-font capture was inspected
  at `build/condition-reference.png` (local artifact, not a golden baseline).
- Backend `python -m ruff check .`: passed.
- Backend `python -X utf8 -m pytest -q`: **1386 passed**.
- `git diff --check`: no whitespace errors.

## Not verified / remaining boundaries

No installed bench/site, connected emulator or backend Playwright dependencies
are available in this workspace. Native database, permissions and real HTTP
tests are written and CI-registered but **not run locally**. The opt-in app flow
requires a disposable inactive v2 definition via ASOUD_E2E_CONDITION_DEFINITION
and ASOUD_E2E_ALLOW_WRITES=true, plus the existing E2E login configuration.
Do not claim production end-to-end completion before those runs succeed.

Deploy the backend contract before the paired app. No data migration is required.
The separate approval correction/amendment feature is not implemented by this
change. Chosen policy: preserve the original, create a linked corrected version
within the same instance, and use native document amendment when applicable.
Existing unrelated unit-management and approval edits are preserved uncommitted;
this report does not claim they have been completed or pushed.
