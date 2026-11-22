---
description: Claim a board task (acts as a lock)
argument-hint: <task-id>
---
Run `bash .hackathon/bin/hk.sh claim $ARGUMENTS`. If TAKEN or LOST RACE, run `/sync` and pick another open task whose contract you can code against; don't wait. If CLAIMED, read only the contract files in that row's ref, then start. Stay inside your owned directories; to touch a shared file (package.json, schema, env), log `CLAIM-FILE <path>` first via `hk.sh log`.
