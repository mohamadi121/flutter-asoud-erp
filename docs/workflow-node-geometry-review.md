# Workflow node geometry — scoped review

## Existing renderer and mapping

The existing `WorkflowGraphCanvas`, `_GraphNode`, `_GraphPainter` and
`_NodeShapePainter` remain authoritative. The presentation-only geometry helper
is shared by painting, ink clipping and line anchors; it is not a second canvas,
workflow model or runtime.

| Existing enum | Shape | Existing theme color |
| --- | --- | --- |
| start | circle | success |
| userTask | rounded rectangle | primary |
| approval | hexagon | purple |
| condition | diamond | warning |
| systemAction | parallelogram | cyan |
| wait | capsule | muted blue-gray |
| end | regular octagon | danger |

No saved identifiers, coordinates, stage types, titles, configuration, route
destinations, API or permissions change. Shapes are derived from the existing
type when rendering old or new graphs, without saving them again. Fill is flat
and pale; border width is shared. Titles wrap without one-line ellipsis, have a
full tooltip, and scale down to fit the fixed existing node box. Existing zoom
remains available. Focus/ink is clipped to the same silhouette.

Approval ports are based on the real saved outgoing routes, not invented flags
or connections. `condition.action` takes precedence over legacy Persian labels.
Only one connected decision exits bottom-center. With two: Approve is physical
right, Reject physical left, Return takes the other side. With all three: Approve
right, Reject left, Return bottom. Unknown legacy routes are still drawn. Changing
the saved route set recomputes anchors without rewriting or deleting routes.

Lines meet actual shape outlines. Reverse approval exits escape around their
source node instead of crossing its contents. Each line still passes through
the original insertion-button center, so '+' coordinates and callbacks are
unchanged. Existing non-approval Persian route labels are retained beside lines.
This is not an auto-layout/obstacle-avoidance engine for arbitrarily overlapping
third-party nodes; users still control node placement as before.

## Changed files

- `lib/features/workflows/presentation/widgets/workflow_graph_canvas.dart`
- `lib/features/workflows/presentation/widgets/workflow_graph_geometry.dart`
- `test/features/workflows/workflow_graph_canvas_test.dart`
- `test/features/workflows/workflow_graph_geometry_test.dart`
- `test/ui/goldens/workflow_designer_390.png`
- `CHANGELOG.md`
- `docs/workflow-node-geometry-review.md`

## Actual verification

- Regression written before the fix: the old renderer failed because a saved
  multiword title was restricted to one line (`Actual: 1`).
- Final related suite: **440 passed** (`test/features/workflows`, dashboard
  localization regression, workflow preview non-goldens, viewport/overflow).
  This includes 60 geometry/canvas tests: seven shapes, RTL 320/390/430, all seven
  approval combinations, legacy actions, boundary contacts, reverse routes,
  insertion-button location, unchanged saved objects, tap/link/drag callbacks.
- `flutter analyze --no-pub`: **No issues found!**
- Designer-only Windows golden regenerated intentionally, visually inspected,
  then re-run without `--update-goldens`: **1 passed**. No other goldens changed.
- Real canvas captures `build/workflow-node-shapes.png` and
  `build/workflow-node-routes.png` were inspected with real Vazirmatn and Material
  fonts. These are ignored test artifacts, not production sample graphs. The
  visual review caught missing Persian paint font and was followed by a fix.
- Full non-golden run: **1907 passed, 9 failed**. Failures were offline record
  ordering/session/queue/retry/reconnect tests and the existing untagged
  `new_request_sheet_golden_test.dart`; the failing existing Continue-label
  regression from an earlier run was repaired, not removed. The final three
  additional reverse-path geometry cases are included in the 440-pass run.
- `git diff --check`: clean.

## Not verified / limits

No live server, device/emulator or real production workflow was opened, edited
or saved. Widget callbacks, existing settings-page regressions and repository
fakes are not a claim of end-to-end production persistence. Extremely long titles
still depend on fit-to-box scaling/tooltip/zoom within the unchanged fixed box.
API, backend and storage files were not modified for this visual request.
