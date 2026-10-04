# Workflow: test, delegate, release, merge

## Local backend bench (user space, no root)
- `~/frappe-dev/start.sh` (MariaDB 10.11 on 3307 root/admin, redis 13000/11000);
  `source ~/frappe-dev/env.sh`; bench at `~/frappe-dev/bench`, site `asoud.test`
  (erpnext, hrms, asoud_erp); `apps/asoud_erp` → symlink to `.workers/backend`.
- After a reboot services are down: run `start.sh` first.
- Pure tests: `~/frappe-dev/bench/env/bin/python -m pytest -p no:cacheprovider -q asoud_erp/tests`.
- Integration: `bench --site asoud.test migrate` then
  `bench --site asoud.test run-tests --app asoud_erp --skip-test-records --module asoud_erp.integration_tests.<module>`;
  all modules: `~/frappe-dev/runall.sh` (reads `~/frappe-dev/modules.txt`).

## Flutter
- SDK at `~/frappe-dev/flutter` (keep off `/tmp`: per-user quota hangs `flutter test`):
  `export PATH=$HOME/frappe-dev/flutter/bin:$PATH`.
- `flutter analyze` must be clean; `flutter test --exclude-tags golden` all green.
- Screenshot review: throwaway test that loads Vazirmatn + MaterialIcons with `FontLoader`,
  sets `tester.view.physicalSize`, `matchesGoldenFile` with `--update-goldens`, view the PNGs,
  then delete them. PDFs: `pdftoppm -png`.

## Workers
- Preferred: Codex (`codex exec -s workspace-write`) with spec-level tasks; it can analyze
  but not run `flutter test` (sandbox) — the manager runs tests. Weekly usage limits.
- Fallback: qwen workers (`qwen-task-loop`/`qwen-worker` skills; server 10.93.0.2:8001)
  need exact old/new steps — prototype in a scratch worktree, generate steps, dry-run,
  byte-compare.
- If no worker is available the user prefers Claude to finish and push (ask once).

## Releases (test builds, GitHub pre-releases)
- App: bump `pubspec.yaml` `version: X.Y.Z+N`, CHANGELOG section, commit
  `chore(release): X.Y.Z+N`, push, wait for Flutter CI, download the debug APK artifact,
  tag `vX.Y.Z` (annotated), `gh release create --prerelease` with the APK
  `asoud-erp-X.Y.Z+N-debug.apk`, notes stating the paired backend version, test count,
  CI run id and SHA-256.
- Backend: bump `asoud_erp/__init__.py` + `pyproject.toml`, CHANGELOG `## X.Y.Z`,
  `chore(release): X.Y.Z`, trigger `gh workflow run erpnext-v15-integration.yml --ref <branch>`,
  tag + pre-release (notes: deploy = pull tag + `bench --site <site> migrate`).
- Release notes in English; explain to the user in Persian.

## Merging
- Open a PR per repo to `main`; the user merges (self-merge is blocked). The app PR may be
  squash-merged, so feature branches end up "behind" — start new work from fresh `origin/main`.
- Another developer (mohamadi121) also pushes to `main` (roles, organization chart): fetch
  and rebase before new work; don't overwrite their changes.

## Team mode (multi-worker, since 2026-10-05)
- tmux session `erp-team` (`tmux attach -t erp-team`); one window per area (live, audit, qa, hr-ui, …).
- Helper `/home/soroush/Desktop/erp/.team/bin/team`: `wt app|be NAME BASE` (worktree `.workers/w-NAME`,
  branch `w/NAME`), `spawn NAME opus|sonnet|codex WINDOW DIR PROMPT`, `say`, `peek`, `key`, `list`, `kill`.
  Prompts in `.team/prompts/`, reports in `.team/reports/NAME.md` (STATUS line), shared rules `.team/RULES.md`.
- Worker models: `claude-gemini` with `GEMINI_MODEL=ag/claude-opus-4-6-thinking` or `ag/claude-sonnet-4-6`
  (9router on 127.0.0.1:20128; its skills dir is `~/.config/claude-gemini/state/skills`);
  Codex `gpt-6-astra` with `model_reasoning_effort=low` and `--dangerously-bypass-approvals-and-sandbox`
  (the sandbox otherwise blocks `flutter test`); a new folder shows a trust dialog (press Enter).
- Workers get `.claude/settings.local.json` deny rules (git push/reset/rebase/checkout…). A shared `pre-push` hook
  refuses pushes from `.workers/w-*`. `graphify-out/`, `.claude/settings.local.json` and `.worker/` are in `info/exclude`.
- Integration branches: app `feat/personnel-v2` in `.workers/flutter`, backend `feat/backend-v2` in `.workers/backend`
  (the bench `apps/asoud_erp` symlink points there).
- Graphify: `graphify update <repo>` (AST, no LLM), then
  `graphify merge-graphs <app>/graphify-out/graph.json <be>/graphify-out/graph.json --out /home/soroush/Desktop/erp/graphify-out/merged-graph.json`.
  Workers query with `graphify query "…" --graph <merged>`. Check graph dates against `git log` before trusting it.
- More worker types in `team spawn`: `qwen` (local `claude-qwen`, Bash/Edit/Read only, ~2k output tokens, extra rules in
  `.team/RULES-qwen.md`; good for audits and infra; ~4–6 parallel requests are fine) and `pickle` (OpenCode
  `opencode/big-pickle`, `--auto` plus a bash deny list from `.team/opencode-perm.json`). Antigravity (claude-gemini) has a
  quota: on 2026-10-05 every Opus/Sonnet worker hit 503 "reset after ~4h" within a minute of starting 6 at once.
- Codex handles spec-level coding tasks; qwen fails on them, so give qwen audits/infra or exact old/new edit tasks.
