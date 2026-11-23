---
description: Check the work before a handoff or push - build, types, lint, tests, secrets, diff - and report PASS/FAIL
argument-hint: [quick|full]  (default quick)
---
Mode: $ARGUMENTS (empty = quick). Run each step that applies to this repo; skip steps whose tool or script doesn't exist. Use `set -o pipefail` and tail long output (`2>&1 | tail -20`); never paste whole logs.
1. Types/lint: `npm run check` if package.json defines it, else `npx --no-install tsc --noEmit` for TypeScript; Python: `python3 -m py_compile` on changed .py files.
2. full only: `npm run build` (or the stack's build); tests if a test script exists (`npm test -- --run` / `pytest -q`).
3. Secrets: `git diff HEAD | grep -nE '(AKIA|ghp_|github_pat_|sk-(ant-)?[A-Za-z0-9_-]{20}|sk_live_|xox[bp]-|BEGIN [A-Z ]*PRIVATE KEY|discord(app)?\.com/api/webhooks)'` must print nothing; `git status --porcelain` must not list .env files.
4. Diff review: `git diff --stat HEAD` and skim the diff for leftovers (debug prints, commented-out blocks, TODOs on the demo path, new `FAKE:` markers that need a pitch note).
5. Report in at most 8 lines: one `PASS`/`FAIL` line per step with the first error (file:line), then the overall verdict. On FAIL fix only what's in your files; build errors you can't fix in 2 tries go to `/build-fix`.
