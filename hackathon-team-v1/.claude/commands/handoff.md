---
description: Finish a task and tell the team in one line
argument-hint: <task-id> <path:line of what to look at>
---
Verify the work runs (smoke test on the demo path). Commit code. Then run `bash .hackathon/bin/hk.sh done $ARGUMENTS`. If anyone is unblocked, also run `hk.sh log "UNBLOCKS @name: <what>"`; if you need an answer, `hk.sh log "ASK @name: <one question>"`. Log lines: telegraphic, pointers (path:line), never code or logs. Settled design choices go in `.hackathon/DECISIONS.md` as one line.
