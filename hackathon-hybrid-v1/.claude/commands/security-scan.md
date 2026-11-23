---
description: Pre-submission security check - committed secrets, keys in code, hidden prompt-injection characters, guard status, public board branch
---
1. Run `node .claude/hooks/hh.js scan` (deterministic, no network except one ls-remote).
2. For each FAIL, fix it now if it's in this repo: `git rm --cached <secret file>` and add it to .gitignore; move hardcoded keys to `.env` and read them from the environment; delete hidden unicode. Tell the human to ROTATE any key that was ever pushed (removing it from the repo isn't enough).
3. WARN items: explain each in one line and what the human should do (e.g. `bash .hackathon/bin/hk.sh archive --delete-remote` after submitting, if the repo is public).
4. Report in <=8 lines.
