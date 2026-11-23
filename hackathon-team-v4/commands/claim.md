---
description: Claim a board task (acts as a lock)
argument-hint: <task-id> [--take]
---
Run `hk claim $ARGUMENTS`.
- CLAIMED / ALREADY YOURS / TOOK-OVER: read only the files in that row's ref (and its deps' refs), then start. Stay in your owned directory; before touching a shared file (package.json, schema, env) run `hk log "CLAIM-FILE <path>"`.
- TAKEN / LOST RACE: `hk sync` and pick another open task whose contract you can code against; don't wait.
- TAKEN ... STALE: the owner has been inactive for a while. Ask the human before taking it over with `--take`.
- OFFLINE: the claim was NOT made. Tell the human; don't start the task as if it were yours.
