---
description: Get a broken build or typecheck passing with minimal changes (delegates to the build-fixer agent)
argument-hint: [error text or the command that fails]
---
1. Reproduce: run the failing command ($ARGUMENTS, else `npm run check`, else `npm run build`) with `2>&1 | tail -40`.
2. Hand the error output and the command to the `build-fixer` agent. It fixes errors only - no refactors, no config loosening, no deleted code.
3. Re-run the command. Report in <=3 lines: what was wrong, what changed (path:line), and PASS/FAIL. If it still fails after the agent's attempt, log `bash .hackathon/bin/hk.sh log "BLOCKED build: <first error>"` and tell the human.
