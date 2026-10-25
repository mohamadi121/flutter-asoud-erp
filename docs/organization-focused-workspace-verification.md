# Focused organization workspace — 2026-10-25

## Baseline and scope

- Compared local/remote branches. The user's corrections were on
  `feat/forms-catalog-integration` at `d21aba6`, not remote main (`fbb2667`).
  Local `226ffc4` and those corrections were merged as `764d1a8` before this work.
- Working branch: `feat/organization-focused-workspace`; the follow-up request
  explicitly authorizes merging and pushing both repositories to main.
- Existing native Department endpoints, chart revision/history store, assignment
  page, shared Persian controls and permission-aware photo loader are reused.
- No production data, assignments, codes or history were migrated or deleted.

## Implementation

- Stable-ID ancestor path, direct-child selection, four-child/two-column pages,
  parent reselection, leaf state and navigation restoration.
- Contextual inline unit/position create, edit, move and deletion review;
  fixed parent/unit for creation, single editor, save/discard/cancel prompts,
  disabled repeat submissions, preserved values on rejected saves.
- Native unit modification tokens and chart revisions are retained. Unit source
  values are captured when editing starts, not silently updated under the form.
- Root job positions are labeled separately from native unit ancestry. The
  fabricated CEO fallback and superseded flat management view were removed.
- Position selection does not alter the unit path. Position pages are bounded,
  occupants show profile avatars (including groups/vacancies/failures), and the
  existing assignment flow refreshes images after returning. Explicit refresh
  also reloads profile images without a separate upload mechanism.
- Unit/position tabs, visual report, existing detail routes and unrelated forms
  remain available. Dead legacy unit-edit branches were removed.
- Matching backend adds `preview_delete_position`; existing chart saves recheck
  occupants, history and direct reporting dependencies under the company lock.
  Backend must be deployed before this frontend. No new schema/migration.

## Follow-up: setup entry and integration

- Managers can reopen the existing template / Excel / manual chooser from the
  workspace. Returning reloads the shared chart and units; existing records are
  never reset. The existing server guard against templates on a nonempty chart
  remains in place and is explained in Persian.
- Inspected `organization_templates.dart`: all five built-in templates, their
  units and position titles are already Persian. They are app-owned suggestions
  sent through the existing Asoud API, not an English ERPNext template catalog.
  No backend migration or renaming of user records is needed for these templates.
- Fetched remote main before integration: frontend `07d851b`, backend `c02cbff`.
  Preserve these newer authentication/onboarding changes alongside this work.
- At the user's explicit request, no tests are run for this follow-up or merged
  result. The results below belong to the earlier pre-merge implementation only.

## Previous verification (before the follow-up and latest-main merge)

- `flutter analyze --no-pub`: no issues.
- Organization-specific tests plus live-shape role tests: 64 passed, including
  the rejected-save test. Covers IDs despite duplicate labels, cycles,
  four-card pagination, path restoration, fixed-parent creation, position save
  at 320/390/430 RTL, capacity lower bound, history preservation, deletion order,
  empty/error/read-only screens, cache refresh and lazy photos.
- Screenshot rendered using the actual OrganizationPage and Vazirmatn fonts at
  390px, inspected locally; reproducible with:

  `flutter test test/features/hr/organization_position_form_fields_test.dart --plain-name "focused organization reference render" --dart-define=ORG_VISUAL=true --update-goldens --no-pub`

  Output: `build/organization-focus-reference.png` (ignored generated artifact).
- Backend `python -m ruff check .`: passed.
- Backend `python -X utf8 -m pytest -q`: 1079 passed. The two added deletion tests
  failed before implementation (missing review function and cascading deletion).
- Full frontend run: 1450 passed, 9 failed. Failures are eight pre-existing
  offline queue/order/Windows SQLite cleanup tests and the untagged new-request
  golden (3.97% difference). They were reproduced on clean baseline `764d1a8`
  in `../organization-baseline`; unrelated code/baselines were not modified.
  Machine-readable result: `build/organization-final-tests.json`.

## Limits / release gates

- A live Frappe bench and emulator credentials are not available here. Backend
  integration coverage was added to the already-CI-listed `test_organization`
  module, and HTTP coverage was added to `e2e/tests/organization.spec.ts` and
  wired into `test:api`. Neither was executed against a live server locally.
- Emulator test `integration_test/organization_test.dart` uses existing E2E login
  defines, plus `ASOUD_E2E_ORG_COMPANY` and `ASOUD_E2E_ORG_PATH` (JSON array of
  native unit IDs, root first). Use a disposable authorized test company with
  fewer than ten direct positions and path children on the first child page.
  It creates, reloads and safely deletes an unassigned test position. It has not
  been run here; do not run against production.
- No pixel-perfect or device/manual end-to-end claim. Surrounding approved tabs
  and shared field/touch-target styling are intentionally preserved. Counts and
  names come from the actual records, not screenshot sample data.
- Native unit endpoints do not expose descriptive code/description or an
  explicit responsible-manager assignment. No unsupported field, guessed
  manager photograph or duplicate record was introduced.
- Existing pending/rejected chart drafts still use the repository's established
  reconciliation workflow; a local pending state is not reported as server save.
