---
description: Claim a board task (acts as a lock)
argument-hint: <task-id> [--take]
---
Run `hk claim $ARGUMENTS`.
- CLAIMED / ALREADY YOURS / TOOK-OVER: the row's ref is the task card (`files: ...; done: ...`). Read `.hackathon/MAP.md` and only the card's files (and its deps' cards), then start. In autonomous mode with lean on (`hk config get lean`), give the task to the `builder` agent instead (id, card, demo path, contracts) and do the handoff from its report; STUCK goes to `deep`. Stay in your owned directory; before touching a shared file (package.json, schema, env) run `hk log "CLAIM-FILE <path>"`.
- TAKEN / LOST RACE: `hk sync` and pick another open task whose contract you can code against; don't wait.
- TAKEN ... STALE: the owner has been inactive for a while. Ask the human before taking it over with `--take`.
- OFFLINE: the claim was NOT made. Tell the human; don't start the task as if it were yours.
