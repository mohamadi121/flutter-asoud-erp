# Full organizational unit details and management

## Connection and boundaries

- The chart opens the existing `_UnitDetails` route using the selected native
  Department ID. The CEO chart position is not synthesized into a Department.
- Details reload `OrganizationRepository.units(company)` and select the exact ID.
  Positions and assignment history come from the same `OrganizationCubit` used
  by the chart. No second repository, endpoint, model, table or permissions were
  introduced. Existing owner-scoped offline read caching remains in effect.
- Unit rename/description, reparent, preview and delete use the existing
  `save_unit`, `preview_delete_unit`, and `delete_unit` methods. Modified/revision,
  company/native permissions, cycle checks and native link blockers remain on
  the server. Transfer does not rewrite positions or their history.
- Position creation/editing uses the existing inline editor and `save_chart`.
  The parent selector is also available during position creation on this page.
  Capacity validation, occupied/history preservation and server reconciliation
  are unchanged.
- Assignment and history are embedded underneath the selected position using
  `_OrganizationAssignments`, which loads the existing real HR employee list.
  Dates remain server-generated when an assignment starts/ends; arbitrary
  backdated/future assignment ranges are **not** supported by the current API
  and were not fabricated or added in this UI change.
- One operation is open at a time. Dirty edits require confirmation before
  switching; the active section stays mounted while scrolling. Back closes an
  operation first, then returns to the still-mounted chart. Unit reload on
  return preserves its selection; deleted units fall back to a valid parent.
- The old separate management route and the incomplete title-only position
  creation widget were removed. No production data was changed during this work.

## Files changed

- `lib/features/hr/presentation/pages/organization_unit_details.dart`: full page,
  native-ID reload, section-local operations, position cards, dirty/back handling.
- `organization_focus.dart` in the same directory: chart details button and
  selection-preserving refresh; remove options used only by the old route.
- `organization_focus_editor.dart`: optional detail-page styling, parent selector
  for new positions, name/description-only unit edit in details mode.
- `organization_assignments.dart`: optional initial history tab; reuse embedded
  assignment; remove obsolete title-only position creation.
- `organization_style.dart`: optional background for the existing shared panel.
- `organization_page.dart`: remove old route part declaration.
- `organization_unit_management.dart`: removed obsolete separate route.
- `organization_workspace.dart`: remove no-longer-used subunit parent argument
  from the separate root unit form; inline subunits use the existing editor.
- `test/features/hr/organization_position_form_fields_test.dart`: native-ID
  navigation, mobile widths, edit/description, draft retention, transfer target
  exclusions and preservation, safe deletion, read-only gates, position/history,
  and opt-in visual render. Existing assertions were adapted to the intentionally
  inline forms without removing their persistence checks.
- `test/features/hr/organization_unit_flows_test.dart`: select the existing safe
  deletion action by its key instead of the obsolete label.
- `integration_test/organization_test.dart`: real-server details save/reopen/
  restore scenario, opt-in via existing test company/login defines.
- `CHANGELOG.md` and this report.

## Verification

- `flutter analyze --no-pub`: no issues (rerun after final changes).
- `flutter test test/features/hr test/features/roles
  test/ui/roles_and_organization_live_shape_test.dart --no-pub
  --exclude-tags golden --reporter expanded`: **419 passed**.
- Final targeted unit/forms/assignment/live-chart run: **61 passed**, including
  draft retention after scrolling at 320/390/430 px RTL.
- Opt-in `full unit details reference render` with `ORG_VISUAL=true` and
  `--update-goldens`: passed; the generated `build/full-unit-details.png` was
  inspected with the real Persian and Material icon fonts. No committed golden
  baseline was overwritten.
- Broad suite run during implementation: **1975 passed, 9 failed**. The failures
  were eight core/offline tests and `new_request_sheet_golden_test.dart`, outside
  the changed organizational UI. Log: `build/unit-details-full-suite.log`.
  These failures were not hidden or changed to obtain a passing report.
- Native Frappe/HRMS integration and emulator execution were **not run**: no
  configured disposable bench/emulator session was used. Real-server persistence
  is therefore not claimed as verified. The opt-in integration scenario must run
  only against a disposable test company, never a production company.

No commit or push was performed as part of this implementation turn.
