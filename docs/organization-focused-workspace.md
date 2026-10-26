# Focused organizational management — implementation notes

The existing OrganizationPage, OrganizationCubit, OrganizationUnitNavigation,
native unit repository, inline editor, compact creation form and assignment
history UI are reused. No native records, IDs, assignments or history are migrated.

## Interaction

- No three-tab navigation on the main workspace. Existing list/report/setup
  capabilities remain accessible through the compact tools menu.
- Initial selection is the real chart root, not the only/first Department.
  Root positions are read from the chart's actual parent links; no fake CEO,
  Department or employee is inserted. Missing roots are explicitly reported.
- Native Department IDs build the selected ancestor path. Only its immediate
  children are shown, two columns and at most four children per page.
- Ancestors stay navy. Tapping an ancestor shortens the path; tapping the root
  resets it. Re-tapping the current unit toggles its children without losing
  the selected details. Card navigation performs no writes.
- Blue section/empty-state boxes, connector lines and slim creation buttons sit
  within the chart. Buttons follow the children/empty state, never precede them.
- One operational form is shown below the chart and above details. Root-level
  creation, selected-unit/position edits and assignments reuse existing forms.
  Existing dirty-form prompts and save/permission/epoch checks remain in use.
- Root-level position creation requires a real Department. Unit and position
  graph types are never inferred from titles. Unit edits do not rename IDs.
- Deletion previews, descendant exclusions, revision checks, active capacity
  checks and server-owned assignment history continue through existing APIs.

## Explicit backend gaps (not simulated)

The current `organization.save_unit` accepts title, parent and group status;
`list_units` does not return a description field. No editable description is
offered as if it could be saved. The UI can display one if a future authorized
response supplies it.

Current chart assignment writes only change active occupant IDs. Start/end
timestamps are stamped and preserved by the server when assignments start/end.
There is no API for arbitrary effective-date ranges or interval-overlap checks.
The inline panel discloses this rather than accepting dates that cannot be saved.
Adding those features requires an agreed backend contract and implementation.

## Verification on Windows

- Whole-project Dart analyze with fatal warnings/infos: no issues.
- Related tests cover 320/390/430 RTL navigation, current-node toggling, root
  return, four-child pagination, unchanged native IDs, dirty-form protection,
  create/edit validation, deletion blockers and personnel/photo/history flows.
- Final targeted run: 39 tests passed; two explicit visual-render cases passed.
- The explicit ORG_VISUAL render writes disposable PNGs under `build/` only;
  main golden baselines are not updated. Rendered output was inspected.
- Full non-golden suite attempt: 1555 passed, 10 failed (nine offline queue/
  ordering/temp-file tests, plus `new_request_sheet_golden_test.dart`). These
  files were not changed here; the whole application is not reported green.
- No production/installed-site writes, migrations or emulator sign-in checks
  were performed. This frontend-only change has not been committed or pushed.
