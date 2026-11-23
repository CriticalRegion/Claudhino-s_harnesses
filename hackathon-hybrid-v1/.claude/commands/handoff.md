---
description: Finish a task, push the code, and tell the team in one line
argument-hint: <task-id> <path:line of what to look at>
---
1. `/verify` (quick) and smoke-test the demo path. Commit.
2. Publish the code: `git pull --rebase --autostash && git push`. If the pre-push check fails, fix it; don't bypass. Teammates can't use work that isn't pushed.
3. `bash .hackathon/bin/hk.sh done $ARGUMENTS`. Teammates whose tasks depend on it are notified automatically. If it says NOT PUSHED, tell the human (offline); `hk.sh sync` retries later.
4. If anyone else is unblocked: `hk.sh log "UNBLOCKS @name: <what>"`. If you need an answer: `hk.sh log "ASK @name: <one question>"`. A settled design choice: `hk.sh decide "<one line>"`. Telegraphic, pointers (path:line), never code or logs.
5. If you deployed: run `/demo-check`.
