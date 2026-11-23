---
description: Refresh the team board and pull teammates' code (cheap)
---
1. `hk sync`. It only touches the board branch, never your code.
2. Pull code: `git pull --rebase --autostash`. On a conflict, resolve it keeping both sides' intent, then `git rebase --continue`. No upstream: skip.
3. Summarise in at most 3 lines only what affects your current task: URGENT FOR YOU lines first, then changed contracts, STALE tasks you could take, DONE you depend on. Don't read other files unless needed.
