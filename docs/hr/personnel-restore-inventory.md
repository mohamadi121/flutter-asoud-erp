# Personnel page restoration inventory

Recorded before removal. Recovery revision: `c71b8866792ea7744e52ba9bae40e6e1a4d8e86e`.
Paths below are under `lib/features/hr/presentation/pages/`. Recover with
`git show c71b886:<path>`. These capabilities are intentionally not ported to
`PersonnelDetailPage`; the product owner will choose any later additions.

| Capability only in the removed page | Recovery location |
| --- | --- |
| Native contract current/history lists, active/upcoming/expired status, remaining days, attachment download | `personnel_file_sections.dart:313`, `personnel_file_sections.dart:474`; overview link `personnel_file_page.dart:421` |
| Contract creation, date validation, terms, signed/final submission switches and 5 MB attachment picker | `personnel_file_sections.dart:579` |
| Promotion/change of designation, department or branch, effective date and remarks | `personnel_file_sections.dart:733`; action `personnel_file_page.dart:336` |
| Document category filters; expiry/expiring/pending verification labels, document number, issue/expiry metadata; identity documents within personal section | `personnel_file_page.dart:546`, `personnel_file_sections.dart:250`, `personnel_file_sections.dart:504`, `personnel_file_sections.dart:546`; overview warning count `personnel_file_page.dart:382` |
| Clickable direct-manager file link; manager role/department card; department hierarchy, direct report count and employee number | `personnel_file_page.dart:389`, `personnel_file_sections.dart:266` |
| Calculated service length; employment status, holiday calendar, default shift, scheduled confirmation fallback and relieving date | `personnel_file_page.dart:419`, `personnel_file_sections.dart:293` |
| Education list, previous employment list, permanent address | `personnel_file_sections.dart:224`, `personnel_file_sections.dart:232`, `personnel_file_sections.dart:243` |
| Native salary structure assignments and history, variable pay, latest payslip, earnings/deductions; separate salary visibility gate | `personnel_file_sections.dart:328` |
| Monthly attendance counts, latest check-in/out and leave balances/pending approvals | `personnel_file_sections.dart:381` |
| Native employment timeline (joining, promotion, transfer, salary, termination), beyond legacy record history | `personnel_file_page.dart:515`, `personnel_file_page.dart:874` |
| Rich activity feed with actor, Jalali timestamp and event-specific icons; full feed view (the old page already has recent record activity) | `personnel_file_page.dart:462`, `personnel_file_page.dart:824` |
| File-header account ⋮ menu: access/account/invitation/login-history entry points (login-history only shows an unavailable-service notice). The same list-row menu remains used | `personnel_file_page.dart:585`; shared implementation `personnel_design.dart:1049` |
| Dedicated file endpoint, legacy fallback banner, own-file constructor, configurable initial tab and pull-to-refresh | `personnel_file_page.dart:147`, `personnel_file_page.dart:283`, `personnel_file_page.dart:661`, `personnel_file_page.dart:682` |
| Separate organization/employment section editors offering unset fields; personal section redirects editing to person master | `personnel_file_sections.dart:148` |
| Header employee-code/local-registration placeholder, initials fallback, typed status labels and bidi-aware field values | `personnel_file_page.dart:3`, `personnel_file_page.dart:721` |
| Persistent edit-file/more-actions footer | `personnel_file_page.dart:596` |

Shared `PersonnelFile`, `PersonnelFileRepository`, `personnelFileFromLegacy`,
record/document helpers and their model/repository tests remain. Employee
`MyInfoPage` stays unchanged. Existing record editing, photos, documents,
revision-aware profile editing, sync retry and local import belong to the
restored page too and are not removed capabilities.
