# Workflow creation and user actions

- Start picker uses the actual header subtitle's bottom in the Navigator overlay;
  a measured tight-height sheet leaves both header lines outside the sheet.
- Module filtering also saves the existing workflow module_key, including after
  an independent design copy. No parallel module/category store is introduced.
- Creation method is inline. Existing readable designs and ready templates are
  sources for independent copies, not in-place rewrites of executed workflows.
- User-action designer configures a Simple or pinned published Form result, never
  execution values. The existing FormFieldsView, tables, formulas and validators
  are reused. Read-only previews cannot upload/remove Files.
- Native task runtime handles Claim, Follow Up, Blocked, separate drafts and
  Complete. The client uses online RPCs and preserves values on rejected writes;
  it does not treat an offline queued operation as successful completion.
- Unit/role assignment uses native choices and runtime subject resolution.
  Original entry values remain immutable; native request editing still requires
  the original owner/state permission. Overdue reassignment remains the existing
  backend capability, not a new unrestricted manual-transfer endpoint.

## Verification boundary

Per owner request, no Flutter tests, backend tests, HTTP suite, emulator, golden
regeneration or live server mutation was executed. Added regressions are not
reported as passing. Static analysis and diff checks only are recorded in the
pull request. Existing Workflow Designer golden PNGs need a separately approved
review/update for the intentional default Persian label change.

Deploy the paired backend first, restart its workers, then release the client.
No new DocType/schema migration. Review the paired backend contract in
`docs/api/workflow-user-actions.md` before production approval.
