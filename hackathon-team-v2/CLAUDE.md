# Hackathon mode
Goal: a working, demoable thing before the deadline. Judges see the demo, not the code.

## Rules
1. Read `.hackathon/PLAN.md` first. Build only what is on the demo path. Anything else goes in "Cut list".
2. Vertical slice first: one end-to-end happy path (input -> core logic -> visible output), then widen.
3. Fake it if the judge can't tell: hardcode, seed data, mock third parties. Mark it with a `FAKE:` comment so the pitch stays honest.
4. Prefer boring, hosted, zero-config: Next.js/Vite, SQLite/Supabase, Vercel/Netlify. No new infra, no auth unless it's the idea.
5. Check docs with context7 before using any library API you aren't sure of. Don't guess, don't debug from memory.
6. Deploy early (first hour) and on every milestone. A live URL beats a perfect localhost.
7. Commit at every working state: `git commit -am "wip: <what works>"`. Push to main only when it runs (the pre-push hook runs `npm run check`).
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
- The board lives on its own git branch, checked out at `.hackathon/state/` (BOARD.md, LOG.md, DECISIONS.md). Read those files freely; change them only through `bash .hackathon/bin/hk.sh` (claim, release, done, add, log, decide). hk.sh never touches your code; push code yourself.
- Start of work: `/sync`. Take work: `/claim <id>`. Finish: `/handoff <id> <path:line>`.
- Edit only your directory (Owners in PLAN.md). `contracts/` is the shared interface: change it only after an `ASK` log line or a `decide` line.
- `TEAM UPDATES` lines appear automatically. Act only if relevant to your task; otherwise ignore. Don't reply to them conversationally.
- Log lines: `HH:MM @name EVENT text`, EVENT in DONE, BLOCKED, ASK @x, CLAIM-FILE <path>, UNBLOCKS @x. One line, pointers not payloads.
- If hk.sh says OFFLINE or NOT PUSHED, tell the human; never assume a claim succeeded.
- More than one round trip on anything means ask the human. Never loop with another agent. Never force-push.
