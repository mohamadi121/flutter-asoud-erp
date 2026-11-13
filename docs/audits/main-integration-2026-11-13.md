# Main integration and root organization follow-up — 2026-11-13

## Scope and baseline

- Feature branch: `fix/org-root-forms`; reviewed main: `c480539`.
- Preserve both the pending audited workflow/org changes and the user's newer
  changes already on main. No force push, main update, deployment, database
  migration, server reset, stash application or historical-data write.
- Backend feature head remains `f7a4000`; no backend source changed in this pass.

## Conflict resolution

Ten conflicted paths were reconciled rather than accepting either side wholesale:
CHANGELOG; the Frappe and preview workflow repositories; workflow entities;
stage settings; condition settings; designer page; stage settings dispatcher;
graph canvas; condition settings tests.

Preserved main's condition-test repository interface, people metadata, workflow
checks, dry-run UI, independent system-workflow copying, supplementary forms,
task handling and node highlighting. Preserved the audited typed condition
inputs, inline validation, draft/start atomicity, wait/end editors, safe path
insertion/deletion and removal of the retired node-side chain.

The existing condition-test endpoint is reused; no second execution engine was
created. Both condition-test repository injection contracts remain supported.

## Proven fixes

- `OrgPosition.toJson`: explicitly serialize `department_id: ''` for a root
  position without a native department. Omission previously lost this intent.
  No Department is fabricated to represent the CEO position.
- `StageSettingsPage._validate`: validate route IDs against the current loaded
  design, not the stale design passed when opening the editor. A newly added
  destination previously appeared selectable but was rejected at save time.
- Retired unused embedded options in the legacy full-page organization creation
  widget; current inline focus editors are unchanged by that cleanup.
- Updated obsolete UI tests to the approved pencil/full-unit-details navigation
  and route controls. Kept capacity, history, persisted ID and invalid-destination
  assertions; tested rejection at the picker and validation layers.

## Test harness portability

Full runs exposed existing Windows fixture issues independently of these edits:
consecutive fake records could receive identical timestamps and reverse FIFO
expectations; a SQLite test deleted its directory before closing the connection.
The fake store now assigns monotonically increasing fixture timestamps, and the
SQLite test closes its database in teardown. Production queue code is unchanged.

The new-request raster test lacked the `golden` tag required by the existing CI
split. It is now tagged, not removed or rebaselined. An explicit earlier run
failed with a 3.97% image difference; that visual baseline remains unresolved.

## Verification

- Regression run before integration fixes: failures retained in local
  `build/merge-focused.log` and `build/merge-full.log`.
- Organization + condition tests: **79 passed** (`merge-focused-4.log`).
- Route/canvas/settings/preview functional tests: **80 passed**
  (`merge-routes-final.log`).
- Offline tests after fixture fixes: **62 passed** (`merge-offline-final.log`).
- `flutter analyze --no-pub`: **No issues found**.
- Final `flutter test --no-pub --exclude-tags golden`: **2313 passed**, zero
  failures, `03:17 +2313: All tests passed!` (`merge-full-verified.log`).

No physical-device/emulator visual inspection or authenticated organization
write against the production server was performed. A passing widget test does
not certify those flows. Graphify CLI is unavailable; the main graph artifacts
were preserved, but not regenerated for these integration edits.
