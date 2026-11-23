---
description: Save where you are (wip commit + a 5-line note) so a /compact, /clear or new session picks up exactly here
argument-hint: [what you're in the middle of]
---
1. If there are working changes that run: `git add -A && git commit -qm "wip: <what works>"` (don't push unless it passes `npm run check`).
2. Write `.hackathon/notes/<your handle>.md` (handle from `.hackathon/.me`; create the folder) with at most 5 lines, overwriting it:
   - Goal: <task id and the outcome you're after>
   - Done: <what works now, with path:line pointers>
   - Next: <the very next concrete step>
   - Gotchas: <anything a fresh context would trip on: env vars, ports, a failed approach to avoid>
   - Context: $ARGUMENTS
3. Say in one line that it's safe to `/compact` (or `/clear`) now: the SessionStart hook will hand this note back with your tasks, uncommitted files and recent commits.
