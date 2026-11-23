---
description: Finish a task: verify, push the code, mark it done, tell the team in one line
argument-hint: <task-id> <path:line of what to look at>
---
1. `/hackathon:verify` (quick) and smoke-test the demo path. Commit.
2. Reviewer: if `hk config get reviewer` prints `on` and `hk clock --minutes` is at most `hk config get polish_at`, give the `reviewer` agent the diff of this task (`git diff @{u}...HEAD`, or the task's commits) and fix every FAIL first.
3. Publish the code: `git pull --rebase --autostash && git push`. If the pre-push check fails, fix it; don't bypass it. Teammates can't use unpushed work.
4. `hk done $ARGUMENTS`. Teammates whose tasks depend on it are notified automatically. NOT PUSHED: tell the human (offline); `hk sync` retries later.
5. If someone else is unblocked: `hk log "UNBLOCKS @name: <what>"`. Need an answer: `hk log "ASK @name: <one question>"`. A settled design choice: `hk decide "<one line>"`. Telegraphic, pointers (path:line), never code or logs.
6. If you deployed: `/hackathon:demo-check`.
