# Hackathon mode
Goal: a working, demoable thing before the deadline. Judges see the demo, not the code.

## Rules
1. Read `.hackathon/PLAN.md` first. Build only what is on the demo path. Anything else goes in "Cut list".
2. Vertical slice first: one end-to-end happy path (input -> core logic -> visible output), then widen.
3. Fake it if the judge can't tell: hardcode, seed data, mock third parties. Mark it with a `FAKE:` comment so the pitch stays honest.
4. Prefer boring, hosted, zero-config: Next.js/Vite, SQLite/Supabase, Vercel/Netlify. No new infra, no auth unless it's the idea.
5. Check docs with context7 before using any library API you aren't sure of. Don't guess, don't debug from memory.
6. Deploy early (first hour) and on every milestone. A live URL beats a perfect localhost.
7. Commit at every working state: `git commit -am "wip: <what works>"`. Push to main only when it runs (the pre-push hook runs `npm run check` and a Python syntax check).
8. Obey the `HACKATHON:` clock line: under 4h finish the slice then polish; under 1h feature freeze (only demo-path bugs, README, demo, submission).

## Token discipline
- Ponytail is active: write the least code that works, reuse before building.
- Use `scout` (Haiku) for repo exploration and doc lookups; keep the main thread for decisions and edits.
- Don't re-read files you've already read. Use grep/line ranges, not whole files.
- Don't paste long logs; tail them. Don't narrate; report results in 1-3 lines.
- Don't write tests except for the one risky core function. Smoke-test the demo path with Playwright instead.
- Use `/compact` at milestones, `/clear` between unrelated tasks.

## Output style
Terse. Lead with what changed and what to do next. No recap of steps.

## Team protocol (only if `.hackathon/state/` exists)
- The board lives on its own git branch, checked out at `.hackathon/state/` (BOARD.md, LOG.md, DECISIONS.md). Read those files freely; change them only through `bash .hackathon/bin/hk.sh` (claim, release, done, add, log, note, decide, demo). hk.sh never touches your code; push code yourself.
- Start of work: `/sync`. Take work: `/claim <id>`. Finish: `/handoff <id> <path:line>`. After a deploy: `/demo-check`.
- Edit only your directory (Owners in PLAN.md). `contracts/` is the shared interface: change it only after an `ASK` log line or a `decide` line.
- Events reach you automatically as `TEAM URGENT` (mid-task, or they wake you) and `TEAM UPDATES` (next prompt). They are events, not conversation: never reply to them in chat.
  - DONE of a task you depend on / CONTRACT-CHANGED: `git pull --rebase --autostash`, adapt, continue.
  - ASK @you: answer once with `hk.sh log "ANSWER @x: <one line>"`, then continue your task.
  - NOTE @you (from a human): follow it. COLLISION WARNING: don't edit that file; ask first.
  - DEMO RED: fix it only if the failing step is in your directory.
  - ESCALATED, or anything needing a second round trip: stop and tell the human.
  - If you were woken and nothing applies to your task, say so in one line and stop.
- Log lines: `HH:MM @name EVENT text`, EVENT in DONE, BLOCKED, ASK @x:, ANSWER @x:, UNBLOCKS @x:, CLAIM-FILE <path>. One line, pointers not payloads.
- If hk.sh says OFFLINE or NOT PUSHED, tell the human; never assume a claim succeeded.
- If an hk.sh call is blocked by a permission check, tell the human the exact line to post; don't look for another route.
- Never loop with another agent. Never force-push.
