# Workflow Start settings — implementation and verification

## Scope

The existing metadata, appearance and creation-method sections are unchanged.
The Start editor adds form/manual mode, moves the existing published-source picker
from User Task, and contains only the four approved additional settings. The
existing Start-circle tap already opens this form and reloads the designer after
save; its identity, coordinates and edges are preserved.

Manual mode is independent of form submission. Existing configured native roles
authorize the actual initiator. A fresh reason is entered when executing, never
reused from a designer-entered text. The manual action appears only with the
server's `can_start_manual` flag. It grants no design/delete/status permissions.

The additional sheet changes only the manager-restart exception. Duplicate-record
protection, manual reason and native start auditing are mandatory server rules.
The disabled reason field previews the runtime input, not a saved fixed reason.
Explicit record restarts also retain existing record ownership/read checks. No
new engine, API or production data mutation is introduced by opening the editor.

## Data and failures

- Existing `save_start_settings` accepts the documented additive v1 settings.
- Definition metadata and Start settings save in two existing operations; a known
  draft identity is retained when phase two fails so retry does not create it twice.
- A Start response without v1 acknowledgement is refused (paired server deployment
  is required). Start configuration/execution do not report offline-queued success.
- The picker chooses only a published form/revision, not a new request/entry.
- User Task source metadata moves only on explicit Start save. Existing task
  fields/layout/content, historical instances and prior records remain intact.
- Running instances block actual Start-policy changes; identical settings are a no-op.
- Manual execution blocks double taps and dismissing the pending dialog, and stops retries after an uncertain network
  response. The user must inspect existing runs before another intentional start.

## Verification (Windows, 2026-11-01)

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --exclude-tags golden test/features/workflows test/ui/workflow_form_page_test.dart`:
  **455 passed**, including **23** new Start/restart behavior/layout tests.
- Real Vazirmatn/MaterialIcons layout captures reviewed at 320/390/430 px in RTL.
  Reproduce with `--dart-define=CAPTURE_WORKFLOW_START=true` and
  `test/features/workflows/workflow_start_layout_test.dart`; captures go to `build/`.
  Reviewed captures: [form](workflow-start-form-390.png),
  [additional settings](workflow-start-additional-390.png),
  [remaining settings](workflow-start-additional-bottom-390.png).
- Full `flutter test --no-pub --exclude-tags golden` before the final dialog-dismissal guard: **1924 passed, 10 failed**.
  Failures are in unchanged offline database/queue/session/retry/reconnect tests
  (including a Windows file-lock cleanup error) and the untagged
  `new_request_sheet_golden_test.dart` reference image. No assertions or golden
  baselines were weakened or regenerated to conceal these failures.
- Backend pure suite and Ruff are reported with the paired backend PR.
- GitHub Linux test/build and form-builder goldens succeeded for the initial
  client commit `d0ee74d`; the subsequent dismissal guard has its own regression.
  The paired backend integration run `41344818476` stopped in the unchanged
  `test_document_templates.test_privileged_roles_request_query_and_permission_pinned`
  (expected an empty HR list, received a request), before reaching the new module.
  The Start module was moved to the front of the same loop without removing any
  existing test; its rerun must be checked before claiming live verification.

## Not verified here

The referenced-execution detail now uses the server's `can_restart` flag to offer
an explicit restart with a fresh reason. It calls the same runtime RPC with the
original reference and `restart: 1`, opens the new execution and preserves the
previous history. No flag grants record read access or changes native ownership.

The first isolated Start CI run (`41345995935`) exposed invalid test assignment:
the special Administrator account is deliberately excluded from native task
assignees. The fixtures now use an ordinary System Manager account with no
Employee record; production assignment rules were not relaxed. The updated live
suite, including restart eligibility assertions, still needs its rerun result.

No Bench/Frappe site, Node/npm or disposable signed-in emulator session is
available on this machine. Real-site integration and HTTP tests are registered
in the backend CI. `integration_test/workflow_start_test.dart` is an opt-in real
sign-in/save/reopen regression for a disposable v1 Manual definition; it requires
the usual `ASOUD_E2E_*` credentials, `ASOUD_E2E_START_DEFINITION` and explicit
`ASOUD_E2E_ALLOW_WRITES=true`. It does not start a real execution. None of these
live tests has been claimed as run, and no production data was reset or started.

Before production rollout, deploy the paired backend/client, restart workers and
run the registered bench/HTTP/emulator checks on an isolated test company.
