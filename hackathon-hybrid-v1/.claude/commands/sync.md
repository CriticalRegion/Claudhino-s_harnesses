---
description: Refresh the team board and pull teammates' code (cheap)
---
1. Run `bash .hackathon/bin/hk.sh sync`. It only touches the board branch, never your code.
2. Pull code: `git pull --rebase --autostash`. If it reports a conflict, resolve it keeping both sides' intent, `git rebase --continue`. If there's no upstream, skip this step.
3. Summarise in <=3 lines only what affects my current task: URGENT FOR YOU lines first, then changed contracts, STALE tasks I could take, DONE I depend on. Don't read other files unless needed.
