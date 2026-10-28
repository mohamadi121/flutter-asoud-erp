# Workflow creation UI and independent template drafts

The supplied HTML is a visual reference, not an instruction to copy its sample
records or simulated stage page. The app keeps the actual workflow designer.

- List creation action is reserved above bottom navigation, not floated over cards.
- Basic metadata and live icon/color preview have separate cards.
- A compact bottom drawer offers Custom or Template mode. Template mode opens a
  real, company-scoped, paged/searchable system-template catalog.
- Cancelled selection changes no mode or metadata. Typed title/description are
  preserved when selecting another template; auto-filled values follow selection.
- Template mode calls `workflow_templates.create_from_template`, not the old
  createDraft endpoint (whose Template flag alone never copied any stages).
- The result opens the same WorkflowDesignerPage. Copies are inactive, unpublished,
  pending review, with fresh graph identities and no execution history or active
  native Workflow link. Original template and its audit/history are not edited.
- Authenticated errors never fall back to sample templates. Catalog is online-only.
- Backend must be deployed/restarted before the app. No schema migration is added.

Static analysis was performed; tests were written/updated but not executed at the
user's request. Real HTTP/site, emulator and pixel-level verification remain
unperformed; existing golden baselines were not regenerated.
