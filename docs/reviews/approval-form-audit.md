# Approval settings audit — 2026-11-03

## Follow-up audit — 2026-11-06 (partial implementation, not completion)

The new attachment was read in full. The existing backend, runtime, stage
normalizer, source-form binding, designer and real stage settings routes were
inspected again. The requirements below remain open; this update does not claim
the complete 20-case runtime matrix or a pixel-identical reference implementation.

Implemented safely in the frontend:

- Collapsible approval/output preview uses the same selected route map as the
  destination picker. No placeholder stage/transition is saved. Missing explicit
  Reject/Return targets are described as the existing runtime fallback, not
  displayed as invented End/User Task nodes.
- Node outlines reuse `WorkflowGraphGeometry.shape`; colors reuse the newly
  exported, unchanged `workflowStageVisual` from the existing Canvas. The
  Canvas's behavior and saved coordinates are unchanged.
- Touching an existing destination opens its actual User Task, Approval,
  Automatic Action, Condition, Wait or End settings page under the same cubit.
  Returning retains the parent form's draft route selection. Destination lists
  read the latest shared design instead of a stale widget snapshot.
- Fixed a reproduced data-preservation bug: unrelated approval saves previously
  reduced a saved list of two roles to just its first role. Unchanged Role or
  Department assignments now preserve the entire original list and show its
  names. Deliberate owner edits still use the existing assignment controls.
  This is not mixed-role/unit multi-approver authoring.

Changed files in this follow-up only:

- `lib/features/workflows/presentation/pages/stage_approval.dart`
- `lib/features/workflows/presentation/pages/stage_settings_page.dart`
- `lib/features/workflows/presentation/widgets/workflow_graph_canvas.dart`
- `test/ui/stage_settings_page_test.dart`
- `CHANGELOG.md` and this audit

The organizational unit changes already in the worktree were preserved. No
backend file, permission, production data, active instance or historical record
was changed. No commit/push/deployment took place.

Blocking product semantics for correction must be settled before implementing
original-data amendments: the current submitted form entry is immutable. Should
correction create an explicitly linked amended version while preserving the
original, or remain a separate correction response? Overwriting the original
entry or silently treating a response as an amendment is not safe. Exact return
to the originating approval also requires a runtime continuation contract.

Other remaining backend work: safe provisional destination creation/cancellation,
atomic stage-plus-route save, version-scoped mixed approver resolution, published
supplementary form binding, and rejection-compatible terminal validation. Merely
adding controls for these would falsely imply unsupported behavior.

Regression evidence: before the role-preservation fix, the test expected
`['Accounts Manager', 'Purchase Manager']` but received only `['Accounts Manager']`.
Preview tests failed on the old UI at 320/390/430 before adding the preview.
The final command and results are recorded at the end of this report. Real-site
integration and the full mandatory runtime matrix have not been executed.

Follow-up verification:

- `flutter analyze --no-pub`: no issues (2.5s).
- `flutter test test/ui/stage_settings_page_test.dart --no-pub --reporter expanded`:
  **23 passed**. Includes preservation of both saved roles and saved departments,
  preview at 320/390/430 RTL, immediate route selection updates, opening the actual
  destination settings and returning without saving the parent draft.
- `flutter test test/features/workflows/workflow_graph_canvas_test.dart
  test/features/workflows/workflow_graph_geometry_test.dart
  test/ui/stage_settings_page_test.dart --no-pub --reporter expanded`:
  **83 passed**. Log: `build/approval-and-graph-regression.log`.
- `git diff --check`: clean.
- These results are local widget/geometry checks, not real runtime/server tests.

Scope: compare the supplied approval/return reference against the current ASOUD
workflow runtime. No production data, API, native permissions or runtime changed.

## Existing capabilities, verified in source

- `stage_settings_page.dart`: stage title/description, role/unit/Employee owner,
  deadline, required approval, optional Reject/Return, existing destination sheet,
  supplementary legacy workflow fields and Any/All policy.
- `workflow.py`: native stage creation, insertion, linking, persisted coordinates,
  setting save and decision-specific `ASOUD Workflow Transition` rows.
- `workflow_runtime.py`: recipients are deduplicated; All waits for every Open task;
  Any cancels remaining tasks after approval. A Reject or Return cancels remaining
  Open tasks of the same stage, then follows that decision route. A missing Reject
  route rejects the instance; a missing Return route uses `select_return_stage`.
- `workflow_graph_canvas.dart` and graph geometry: the existing seven node types;
  no alternative graph model is necessary.
- `workflow_submission_source.py`: pinned source form and permission-checked,
  sanitized original snapshots. Submitted request entries stay immutable.

## Safe changes implemented here

- White shared cards for stage fields, approval information, single owner,
  deadline, decisions and colored output routes; existing purple identity/header
  and save/cancel remain. No unrelated stage form redesigned.
- Read-only source-form design preview uses existing `forms.get_form` with the
  Start-selected revision and existing form renderer. No duplicate source choice,
  fake request values, entry submission or extra business record.
- Existing supplementary workflow-field editor is retained and moved into the
  information section; it is NOT falsely presented as a published form binding.
- New unconfigured approval uses All; explicitly saved Any and completed legacy
  stages retain their policy. The existing policy selector remains available.
- Disabling a decision with an explicit route asks for confirmation before save
  may remove that connection. The destination stage is never deleted. Previously
  disabled routes are not silently cleared by an unrelated edit.
- Missing destination metadata no longer falls back to a raw stage id in the UI.

## Not implemented; contract/runtime work required

1. **Mixed approver rows:** current assignment has one native assignment type;
   role lists or Employee lists are possible but mixed Role + Department rows
   require an additive, company-scoped resolver contract. Existing role selection
   also represents only the first saved role; do not claim multi-row completion.
   The legacy role resolver reads Has Role globally; do not equate that with
   the newer User Action resolver's explicit active-company/form filtering.
2. **Published supplementary Form Revision:** current Approval normalizer accepts
   workflow `form_fields`, not the User Action `result_form` binding. Copying the
   picker alone would not persist formulas/tables or enforce runtime permissions.
3. **Create destination and cancel safely:** current stage APIs persist immediately;
   no scoped delete-unconfigured-stage operation exists. `add_workflow_stage`
   cannot branch after a stage that already has an exit. Do not simulate rollback
   by deleting an unrelated saved node or its transitions from the client.
4. **Correction continuation:** runtime reactivates the chosen User Task; its
   ordinary outgoing Canvas route determines where it goes next. Returning to
   the exact originating approval is not guaranteed for arbitrary shared graphs.
   A continuation marker/validated return contract is needed, preserving history.
5. **Terminal consistency:** End derives status from its own `outcome`. Reject
   routed to an End configured Completed can therefore finish Completed. Through
   arbitrary automatic stages, rejected intent is not automatically propagated.
   Need a validated outcome/continuation contract, not a fabricated client flag.
6. **Atomic configuration + routes:** frontend still saves settings then routes
   through two existing calls. Single-request atomicity and revision checks must
   be added server-side before claiming all-or-nothing persistence.
7. **Live editable original:** requesting the newest original data does not permit
   overwriting immutable submitted entries or bypassing document rights. Amendments
   must be explicitly designed; a stage form is not a replacement original ledger.
8. Inline editable graph, new-node launch/rollback, draft/publication buttons and
   full mandatory-runtime test matrix are deferred with the above contracts.

## Product/security decisions

- Preserve existing Any definitions versus explicitly migrate selected designs
  to All. This change never migrates history or active workflows.
- Existing Reject/Return is a veto that cancels peer tasks; retaining that policy
  is compatible. Changing it requires a product decision, not just new labels.
- Direct correction of the original submission versus a separate correction
  action: settle amendment semantics before routing v1 action reports as edits.

Only local code is changed. No main push, deployment or historical-data rewrite
is included in this task. Verification results must be reported separately.

## Verification completed

- `flutter analyze --no-pub`: No issues found (2.1s).
- `flutter test test/ui/stage_settings_page_test.dart --no-pub --reporter expanded`:
  17 tests passed (4s). Includes 320/390/430 RTL layout, source revision preview
  with no entry submit, All for new versus preserved Any, confirmation cancel/
  accept, preservation of previously disabled stored routes, current user-action
  controls and existing approval/unit/automatic-stage cases.
- `git diff --check`: clean.
- Initial local failures concerned exact starred-label lookup and scrolling to
  the moved owner section; locators were corrected without removing expectations.
- No real-site, production, full-suite, golden or end-to-end verification. The
  supplied 20-case runtime matrix is not claimed as completed. No pixel-exact
  screenshot comparison is claimed.
