# Login, first-login onboarding, roles — audit and client contract

Status legend: **healthy** (exists, kept), **fix** (exists, changed), **missing** (added now),
**investigate** (blocked on the backend or on a decision).

## 1. Audit (client side)

| Feature | Before | Status | Now |
|---|---|---|---|
| Login screen, server URL | `LoginPage`: 3 fields, free-text URL, `http` default | fix | compact RTL page, URL validated by `ServerUrlPolicy` (https required in release unless the build server / `ALLOWED_CLEARTEXT_HOSTS`; optional `ALLOWED_SERVER_HOSTS` allow-list) |
| Last server | `SecureServerAddressStore` | healthy | kept, plus `SavedCredentialsStore.rememberServer` |
| Username memory | none | missing | per server, in secure storage; editable and clearable |
| Save password checkbox | none | missing | default off; OS secure storage only (`flutter_secure_storage`); web stores nothing and relies on `AutofillGroup`/autofill hints; per server+username; delete via unticking, «پاک‌کردن», or امنیت حساب |
| Biometrics | none | healthy | none added; test asserts no fingerprint/face UI |
| Forgot password | none | missing | link shown only when an `AccountRepository` exists; page calls `account_security.request_password_reset` then `confirm_password_reset` |
| Logout | `SettingsDashboardContent._confirmLogout` | fix | shared `signOutToLogin`: server revoke, local clear, back to login; saved password is NOT deleted; failure of the revoke call is reported |
| Session restore | `SplashPage` → `DashboardLandingPage` | fix | → `PostLoginPage` (server login state) |
| Roles from server | `current_user` (roles only) | fix | `session.login_state` (flags, offices, profile) |
| First office | `FirstOfficeCard` → `OfficeFormPage` | healthy | same form reused; new optional `onCreated` hook continues to the profile instead of the dashboard |
| Admin initial profile | none (only the mockup) | missing | `AdminProfilePage` per image1.png / spec 15-20 (no step bar, no bottom nav, read-only account card, optional card kept mounted, real save, double-submit guard) |
| Change password | none | missing | one `ChangePasswordPage` for forced change, profile form, and بیشتر ← حساب کاربری ← امنیت حساب |
| Setup card | `_SetupProgress` text «راه‌اندازی دفتر هنوز کامل نیست» | fix | titled «راه‌اندازی دفتر کار», «ادامه راه‌اندازی», real step count from `Office.savedStepCount`, shown only to users who may configure |
| Home buttons | operations sheet | fix | accounting entry follows `resolveHomeAction` (ready/needs-setup/denied). There is no module enabled/disabled status on the backend, so only ready / needs-setup / denied occur |
| Roles page | tree of managed roles | fix | `scope`/`system` parsed; «سطح دسترسی: سراسری» and «مشاهده مجوزها» (permission preview); system roles are inspect-only |
| User access modes | simple / medium / advanced | fix | advanced showed the same table as medium (only expanded). Now simple = per-module view switch, medium = 4-operation matrix, advanced = every operation the resource supports, one checkbox each |
| Create-office permission | role-name based (`System Manager`) | fix | `Capabilities.canCreateOffice` = system admin **or** role `ASOUD Office Creator` (`login_state.capabilities.create_office`); hides create buttons and the first-office card |
| Work report → superior | only «ذخیره پیش‌نویس» | missing | «ارسال به مافوق» → `hr.save_report` with `status: Submitted` |
| Directives (issue) for admin | create menu | fix | shows the server's real reason |

## 2. Root cause: admin cannot issue directives / send work reports

Backend, read only (`asoud_erp/api/v1/directives.py`, `hr.py`):

* `directives._employee(company)` requires an **active Employee linked to the session user in that company**
  (`frappe.throw(... PermissionError)` otherwise), and `active_user()` explicitly rejects `Administrator`.
* `directives.options` returns `allowed_actions=["save_draft","issue"]` only if `_people()` is non-empty, and
  `_people()` lists only direct reports (`Employee.reports_to == my employee`). The system admin has no
  Employee and no subordinates, so «صدور دستور» is disabled.
* `hr._employee_for_user()` throws «No active Employee is linked to this user», so `list_reports`/`save_report`
  fail for the admin; the client used to show an empty list instead of the error, and `save_report` only ever stores
  a draft: there was no «send to superior» call on either side.

Resolved on the backend (see section 4 and `docs/api/login-onboarding.md`): the administrator needs no Employee
record, `ASOUD Work Report.reporter` records the sender, the whole company is the team, reports with no direct
superior go to the manager pool. There is no separate submit method: sending is `hr.save_report` with
`status: "Submitted"`. Client changes: real reasons are shown, the send action calls it.

## 3. Decisions kept from the spec

* No account-creation screen; no sample data; no new role/ACL system; no biometrics.
* Passwords never touch `callAsoudMethod` (it stages writes in the offline SQLite queue): account calls use `callMethod`.

## 4. Backend methods the client calls (real contract, namespace `asoud_erp.api.v1`)

Source of truth: backend `CONTRACT.md` and `docs/api/login-onboarding.md`, checked against
`session.py`, `onboarding.py`, `account_security.py`, `hr_onboarding.py`, `role_access.py`,
`role_management.py`, `user_access.py`, `hr.py`, `directives.py`. The first draft of this section listed
proposed names (`account.*`, `hr.submit_report`); none of them exist. All answers use the
`{ok, data, meta}` envelope. `callMethod` is used (never `callAsoudMethod`, which queues writes offline).

| Method | Args | `data` used by the client |
|---|---|---|
| `session.login_state` (GET) | – | `user{id,full_name,first_name,last_name,mobile,email}`, `account{active,must_change_password,temporary_password_expired}`, `roles[]`, `is_system_admin`, `role_title`, `scope`, `capabilities{create_office,manage_roles,delegate_roles,register_personnel}`, `offices[{id,title,office_type,roles,office_roles}]`, `selected_office`, `first_office_exists`, `admin_profile_complete`, `verification`, `next{route,office,message}`. The client obeys `next.route` (`account-disabled`, `change-password`, `create-first-office`, `complete-admin-profile`, `office-select`, `home`, `no-office`; unknown = no-office). |
| `session.logout` (POST) | – | `{revoked}`; `false` is reported to the user. Local credentials are dropped either way. |
| `session.select_office` | `company` | fresh `login_state` |
| `onboarding.create_first_office` | same as `setup.save_office` | `{created, already_exists, office}`; online only; used by the first-login office form |
| `onboarding.get_admin_profile` (GET) | – | `username, role, active, first_name, last_name, mobile, national_id, email, mobile_verified, email_verified, completed` |
| `onboarding.save_admin_profile` | `first_name,last_name,mobile,national_id?,email?` | same + `person`; the client then re-reads `login_state` |
| `account_security.change_password` | `current_password,new_password,repeat_password` | `{changed, must_change_password, other_sessions_revoked, reauthentication_required_for_saved_credentials}`. A wrong current password, weak password and the 5/15-min lock are `ValidationError` = HTTP **417** with a Persian sentence (shown as sent); the session is **not** cleared (only 401 clears it). |
| `account_security.recovery_status` (guest) | – | `{available}`; the forgot-password link is shown only when true |
| `account_security.request_password_reset` (guest) | `identifier` | `{requested, expires_in_minutes}` |
| `account_security.confirm_password_reset` (guest) | `identifier,code,new_password,repeat_password` | `{changed, login_required}` |
| `account_security.activate_account` (guest) | same | invitation activation (72 h code) |
| `role_management.catalog` | – | adds `system_roles[]` (`SYSTEM_ADMIN`, `scope`, `scope_title`, `holders`), rows carry `scope`, `system` |
| `role_management.system_admin_permissions` | – | `capabilities[{key,module,title,gate,granted}]`, `document_permissions[{doctype,actions}]` |
| `role_management.save_role` | payload + `scope` (`global`/`office`) | role row |
| `user_access.editor` | `code,user?` | `catalog[{module,doctype,title,actions(medium),advanced_actions,levels{simple,medium,advanced}}]`, `grants`, `advanced_grants`, `inherited`, `inherited_advanced`, `token` |
| `user_access.apply` | payload `{code,user,token,grants,advanced_grants}` | `{applied, affected_users}` |
| `role_access.assign_role` / `unassign_role` | `user,role,company?` | `{user, role, scope, company, assigned|removed, already_assigned}`; office roles need `company` |
| `role_access.list_office_roles` | `user` | `{user, assignments[{company, role, granted_by, granted_on}]}` |
| `hr.save_report` | payload `{name?, report_date, status:"Submitted", activities[]}` | `{name,status,report_date,total_minutes,review{route,superior,superior_name,note}}`. This is the real send; there is no `submit_report`. At least one activity is required. |
| `hr_onboarding.issue_temporary_password` | `party_profile` | `{method, temporary_password, expires_in_hours, must_change_on_first_login}` (shown once; UI in personnel access) |
| `hr_onboarding.register_personnel` / `bootstrap_hr_lead` | see backend doc | models and repository exist (`HrOnboardingRepository`); **no UI is wired** to them yet |

Temporary password: the server refuses every `/api/method/*` call except `session.login_state`,
`session.logout`, `account_security.change_password`, `logout`, `frappe.auth.get_logged_user`, `frappe.ping`
(HTTP 403). So the sign-in does not require `auth.current_user` to succeed (403 is tolerated), the post-login
step reads `login_state`, and `change-password` opens with no way back. An expired temporary password fails the
login with a Persian 401 sentence, which the login screen now shows as sent.

`current_user` does not return `permissions`; the create-office right is `login_state.capabilities.create_office`
or the native role `ASOUD Office Creator` (the client derives `Capabilities.canCreateOffice` from the role).

Setup state: `setup.get_setup_status` (`office_saved`, `accounting_saved`, `roles_saved`, `complete`) drives the
home card. **The backend has no module enabled/disabled status**, so `ModuleState.disabled` is never produced and
no «فعال‌سازی» action is shown.

## 5. Not verified

* No emulator/device run, no real server run: everything above is covered by widget/unit tests with fakes.
* The mockup was matched by structure and text; no pixel comparison was made.
* Web autofill behaviour was not exercised in a browser.
