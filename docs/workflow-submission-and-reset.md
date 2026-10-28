# Workflow source and temporary setup reset

The request/document picker chooses which published form submission enters this
workflow, not a reusable schema to fill again in a task. `submission_source`
contains trusted form/revision identity. The source's original ASOUD Form Entry
is referenced by the existing workflow instance; documents retain their native
reference and normal posting permissions. The task renders `submitted_form`
read-only with snapshot rendering (no recalculation/re-entry). Private attachments
and declared sensitive fields are omitted by the server. Other stage controls and
saved legacy stages remain compatible. A changed published revision requires
explicit rebinding, and an inactive/incomplete workflow rejects submission clearly.

The temporary login reset action authenticates normally before opening its screen.
Raw online RPC avoids ever queuing the confirmation password. The server decides
authority and exact scope. Pending offline writes block reset on the device.
Preview, backup acknowledgment, typed phrase and fresh password precede queueing.
Queued/running jobs are followed by server job ID; missing/failed status never
claims success or resubmits deletion. Reopening resumes a pending operation.
Confirmed completion signs out and returns to the normal login router. Native
username/password and system authority stay intact; no live reset was performed.

Deploy the paired backend, run `bench migrate`, restart workers and enable the
temporary `asoud_allow_setup_reset` site flag only when deliberately using it.
Disable it afterward. Long-queue worker availability is required. Operational or
unsupported dependencies stop deletion, not a forced wipe. Direct DB/bench writes
must be paused during this administrative operation.

Tests were authored, not executed at the owner's request. Static analysis is not
live server/device or pixel-level verification. The attachment rows in additional
settings report existing capabilities; no independent attachment permission is
granted by this visual redesign. Ordinary native document permissions still apply.
