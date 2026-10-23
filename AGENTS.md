# Agent guidelines — ASOUD ERP Flutter app

Read this whole file before you change anything. It applies to every coding agent and every
human working in this repository. Each rule below exists because the mistake really happened
here and had to be fixed afterwards.

The backend is the Frappe app `asoud_erp` (`frappe-erp-next-2`, see its `AGENTS.md`). Users are
Iranian companies: the UI is Persian, right-to-left, with Jalali dates.

## 1. Structure

- Features live in `lib/features/<feature>/` with `data/` (repositories), `presentation/` (pages, widgets, cubits).
- Shared UI comes from `lib/core/widgets/`:
  - `asoud_ui.dart` and `asoud_form.dart` for cards, fields and buttons;
  - `asoud_jalali_picker.dart` for dates;
  - `states.dart` (`ErrorState`, `EmptyState`, `ComingSoonState`) for empty, error and "coming soon" states.
  Do not build a second card or button style per screen.
- Shared helpers in `lib/core/utils/`:
  - `jalali_date.dart` (`formatJalaliIso`, `toPersianDigits`);
  - `persian_format.dart`;
  - `persian_server_values.dart`, which maps ERPNext enums, roles and stages to Persian;
  - `failure_message.dart` (`failureMessage`, `failureIsForbidden`, `failureCanRetry`).
- Network goes through `lib/core/network/frappe_client.dart`. Never call `http` directly from a page.
- Put new server calls in a **new or feature-specific repository**. Adding methods to `WorkflowRepository` breaks every test fake. Follow the pattern of `WorkflowAutomationRepository` and `PersonnelFileRepository`.

## 2. Text, dates and layout

- Every user-visible string is Persian. No English labels, raw ERPNext names (`Draft`, `HR Manager`), ids (`PREVIEW-*`, `SYS-`, `WF-`, `LOCAL-`) or `ApiException(...)` text on screen.
- Dates are Jalali, digits Persian. Use only the shared helpers. No per-screen `if` chains for months or statuses.
- Latin values (emails, codes, IBAN, `O+`) are shown LTR inside RTL text.
- Every screen must work at **320, 390 and 430 px width in RTL** without overflow. Write widget tests at those sizes. Bottom sheets use `isScrollControlled` and a scroll view.
- Pages pushed in tests are LTR unless `MaterialApp.builder` wraps them in RTL `Directionality`. Add the wrapper in tests.

## 3. Calling the backend

- **Read the backend endpoint before you call it**: method path, arguments, required roles, and the exact response keys inside `success(data, meta)`. Never guess a response shape.
- Test fakes must return the JSON the backend really returns, copied from the backend code or a real call. Guessed shapes caused «۰ نقش» and a setup card that never finished.
- Failures are different kinds and need different Persian messages: 401/403 (no permission), 417 (validation; show the server's Persian message), 5xx, timeout, no connection. Use `failureMessage`. Do not show «ارتباط با سرور برقرار نشد» for everything.
- A read-only endpoint whose name does not look like a read (`catalog`, `directory`, `editor`, `organization_tree`, …) must be added to `isReadOnlyMethod`. Otherwise it is queued as an offline write and the list looks empty.
- Ship the endpoint and the app call together. A call to a method the server does not have returns 417, and the user sees an "outage".
- Do not assume the user has an Employee record or manager roles. A 403 from setup status means "no office access", not "offline".

## 4. States and controls

- Every cubit/provider ends in *loaded* or *error*. An endless «در حال دریافت» is a bug.
- No blank pages: every empty or failed state shows a Persian sentence with the reason and, if it makes sense, a retry button.
- No dead controls: every button navigates, performs its action, shows «به‌زودی», or shows a validation message that names the missing field.
- Hide or disable write actions the user's roles cannot perform. Do not let them fail with 403 after a tap.

## 5. Offline preview and demo data

- The offline preview uses the **same code path** as the signed-in app with a local repository. Do not add separate `if (offline)` screens.
- Decide preview vs signed-in from `FrappeApiClient.isAuthenticated`, never a hard-coded flag.
- Preview data must not contain fake identities, fake amounts presented as real, or preview ids visible to the user.

## 6. Form builder and request presets

- `lib/features/form_builder/` has one schema contract shared with the backend (`docs/api/forms.md` in the backend repo). A key exists only if all of these support it: the runtime renders it, the editor can set it, the backend validator accepts it, and tests prove it. **Do not invent keys** (`system_source`, `system_field`, made-up `source` values). A preset that uses unsupported keys looks right in code and does nothing at runtime.
- Link sources are limited to those the backend supports (Employee, Customer, Supplier, Item, Warehouse, Account, Cost Center, Project, Department). A new source is a feature on both sides, not a string in a preset.
- Auto-filled values use `default_source` (`user`, `company`, `today`, `employee`, `department`, `designation`, `joining_date`). Never write a literal default like «دریافت خودکار» or a sample name.
- Presets are raw reusable forms: no fixed approver, workflow, buttons, office field, fake data or side effects. A workflow belongs in the workflow designer.
- Do not leave empty sections or cards "for later". Remove them or give them real fields.
- Old saved forms must render exactly as before when you add a capability. New keys are optional and additive; `schema_version` stays the same unless a migration is written.

## 7. Performance

- Lists that can grow (personnel, requests, history, org chart) are paginated or lazily built (`ListView.builder`). Never load everything at once.
- Images and photos load lazily, with a size limit and cache. Do not download every employee photo when a page opens.
- Do not call the server inside `build()` or once per row. Load once in the cubit, and batch.

## 8. Tests

- Run before every commit: `flutter analyze` (zero issues) and `flutter test --exclude-tags golden` (all pass). CI runs exactly these.
- One bug, one commit, one regression test that fails before the fix.
- **Never weaken or delete an existing test to make your change pass.** If the behavior changed on purpose, update the expectation and explain why in the commit message.
- Goldens:
  - `test/ui/goldens` are Windows baselines. Never regenerate them on Linux.
  - The form-builder goldens run in CI on Linux. Regenerate a golden only when the visible change is intentional, and look at the new PNG before committing it.
- Never hard-code today's date in a test; compute it.
- `contains(map)` compares identity. Use `contains(equals(...))`.
- Do not run `dart format` on existing files: this SDK reformats the whole file and the diff becomes unreviewable. Format only files you created.

## 9. Code hygiene

- Do not return a Future from a `setState` callback.
- Dispose dialog `TextEditingController`s inside the dialog widget, not right after `showDialog`.
- Never store the password. The session and server address live in secure storage (`session_vault.dart`).
- The main `android/app/src/main/AndroidManifest.xml` keeps `INTERNET` and `usesCleartextTraffic="true"`. `test/android_manifest_test.dart` guards it. A release APK must be smoke-tested with a real sign-in.

## 10. Git and pull requests

- Never push to `main` directly. Work on a branch (`feat/...`, `fix/...`) and open a pull request; the other developer reviews and merges.
- One topic per commit, with a conventional message that says what changed (`fix(hr): load personnel photos lazily`). Messages like `codex changes` or `update` are not acceptable.
- Large UI changes are split into reviewable PRs (data layer, screen, tests).
- The PR description lists the screens touched, screenshots at 390 px for visible changes, and the real output of `flutter analyze` and `flutter test`.
- Add a `CHANGELOG.md` entry under `## Unreleased` (create it at the top if missing) for every user-visible change.
- Never commit secrets, passwords, tokens or signing keys.

## 11. Before you say "done"

- Re-read your diff from top to bottom.
- Open the screen at 320 and 390 px in RTL, with no server (offline preview) and signed in as a non-manager user.
- Write down what you did **not** test. A report that says "all tests pass" without the command output will be rejected.
