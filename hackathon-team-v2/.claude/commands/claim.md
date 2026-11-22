---
description: Claim a board task (acts as a lock)
argument-hint: <task-id>
---
Run `bash .hackathon/bin/hk.sh claim $ARGUMENTS`.
- CLAIMED / ALREADY YOURS: read only the contract files in that row's ref, then start. Stay inside your owned directory; before touching a shared file (package.json, schema, env) run `bash .hackathon/bin/hk.sh log "CLAIM-FILE <path>"`.
- TAKEN / LOST RACE: run `bash .hackathon/bin/hk.sh sync` and pick another open task whose contract you can code against; don't wait.
- OFFLINE: the claim was NOT made. Tell the human; don't start the task as if it were yours.
