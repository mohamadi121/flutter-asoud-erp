# Gotchas (learned the hard way)

## "I can't find / it doesn't work" reports
1. Which build? APK filename `asoud-erp-<version>-debug.apk`; versions bump per release.
2. Is the server reachable and on the matching backend tag? Without a server the app is in
   the **offline preview**; features without a local fallback show «دریافت ناموفق».
3. Manager vs employee-only user (different home). Quick actions on the home page need an
   office selected; they are near the bottom (grid scroll: in widget tests use
   `dragUntilVisible` on the outer Scrollable, `ensureVisible` hits the inner GridView).
4. Verify the code is really in the APK: unzip `assets/flutter_assets/kernel_blob.bin`
   and search the UTF-8 Persian strings.
5. Debug APKs are ~170 MB (JIT kernel, 3 ABIs, Vulkan validation layer). A release
   `--split-per-abi` build is far smaller; there is no release keystore yet (debug signing).

## Backend
- `run-tests --app asoud_erp` fails on Payment Gateway test records → run per module.
- `frappe.only_for` is a no-op in tests; use `require_roles`.
- ERPNext `before_tests` deletes Item Prices; fixtures recreate them. Use leaf groups
  (`fixtures.leaf`) for Customer/Item Group. Default tax templates change totals → assert nets.
- HRMS and POS commit internally → use fresh records per run.
- A new workflow definition needs a native Frappe `Workflow` linked when Active.
- Frappe returns 417 for missing whitelisted methods; the app maps unknown statuses to
  "network" («ارتباط با سرور برقرار نشد»), so an old server looks like an outage.
- IBAN validation needs a valid IBAN; uploaded PDFs must be real PDFs (pypdf).
- Importing a TestCase class into another test module runs its tests twice.

## Flutter
- `dart format` on this SDK reformats untouched files and can introduce lint
  (`curly_braces_in_flow_control_structures`); format only files you changed and revert
  the rest. Run `flutter pub get` before formatting/analyzing a fresh worktree.
- `contains(map)` in tests compares identity → use `contains(equals(...))`.
- Never return a Future from a `setState` callback.
- Dispose dialog TextEditingControllers inside the dialog widget (disposing right after
  `showDialog` crashes during the close animation).
- Adding a method to `WorkflowRepository` breaks every test fake → put new server calls
  in a separate repository (pattern: `WorkflowAutomationRepository`, `PersonnelFileRepository`).
- Widget tests: pushed routes are LTR unless `MaterialApp.builder` wraps them in RTL
  `Directionality`; tooltips/ExpansionTiles/bottom sheets overflow at 320 px — make sheets
  scrollable (`isScrollControlled` + `SingleChildScrollView`).
- Golden tests are excluded in CI (`--exclude-tags golden`).
- Bidi: Latin/number values (O+, emails, codes) need LTR; Persian strings starting with
  digits must stay RTL (`_isLtrValue`).

## Personnel file (state on 2026-10-05, main 44ee44c)
- Two «پرونده پرسنلی» pages existed: list → `PersonnelFilePage` (new, personnel_file API, 4 tabs) → «ویرایش اطلاعات»
  → `PersonnelDetailPage` (old, `_PersonnelOverview`, own tabs). The product owner wants ONE page («after» design):
  compact header (standard employee code, never a LOCAL- id), tabs نمای کلی | اطلاعات پرسنلی | سوابق | مدارک,
  «ویرایش پرونده» switches to the info tab (no new page), «اطلاعات فردی» = Person master (edit in اشخاص و شرکت‌ها,
  no HR copy), ⋮ = account actions only (دسترسی، فعال/غیرفعال، ارسال مجدد دعوت فقط برای حساب واردنشده، سوابق ورود),
  and no «حذف حساب کاربری».
- The list row ⋮ (`personnel_design.dart` `_PersonnelRow`) had «سوابق ورود»/«حذف حساب» with no API («این قابلیت هنوز API فعال ندارد»).
- Another developer (mohamadi121) pushes large UI changes to main (request builder, roles, org chart): pull first.
