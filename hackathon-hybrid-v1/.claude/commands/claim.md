---
description: Claim a board task (acts as a lock)
argument-hint: <task-id> [--take]
---
Run `bash .hackathon/bin/hk.sh claim $ARGUMENTS`.
- CLAIMED / ALREADY YOURS / TOOK-OVER: read only the contract files in that row's ref (and the refs of its deps), then start. Stay inside your owned directory; before touching a shared file (package.json, schema, env) run `bash .hackathon/bin/hk.sh log "CLAIM-FILE <path>"`.
- TAKEN / LOST RACE: run `bash .hackathon/bin/hk.sh sync` and pick another open task whose contract you can code against; don't wait.
- TAKEN ... STALE: the owner has been inactive for 45+ min. Ask the human before taking it over with `--take`.
- OFFLINE: the claim was NOT made. Tell the human; don't start the task as if it were yours.
