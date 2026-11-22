# Hackathon mode
Goal: a working, demoable thing before the deadline. Judges see the demo, not the code.

## Rules
1. Read `.hackathon/PLAN.md` first. Build only what is on the demo path. Anything else goes in "Cut list".
2. Vertical slice first: one end-to-end happy path (input -> core logic -> visible output), then widen.
3. Fake it if the judge can't tell: hardcode, seed data, mock third parties. Mark with `// FAKE:` so the pitch stays honest.
4. Prefer boring, hosted, zero-config: Next.js/Vite, SQLite/Supabase, Vercel/Netlify. No new infra, no auth unless it's the idea.
5. Check docs with context7 before using any library API you aren't sure of. Don't guess, don't debug from memory.
6. Deploy early (first hour) and on every milestone. A live URL beats a perfect localhost.
7. Commit at every working state: `git commit -am "wip: <what works>"`. Never leave main broken in the last hour.
8. Last 20% of time: feature freeze. Only bugs, demo script, README, pitch.

## Token discipline
- Ponytail is active: write the least code that works, reuse before building.
- Use `scout` (Haiku) for repo exploration and doc lookups; keep the main thread for decisions and edits.
- Don't re-read files you've already read. Use grep/line ranges, not whole files.
- Don't paste long logs; tail them. Don't narrate; report results in 1-3 lines.
- Don't write tests except for the one risky core function. Smoke-test the demo path with Playwright instead.
- Use `/compact` at milestones, `/clear` between unrelated tasks.

## Output style
Terse. Lead with what changed and what to do next. No recap of steps.

## Team protocol (multiple agents, one repo)
- Git is the message bus. Agents never message each other; they read/write `.hackathon/BOARD.md`, `LOG.md`, `DECISIONS.md` through `bash .hackathon/bin/hk.sh`.
- First time: `hk.sh init <yourname>`. Start of work: `/sync`. Take work: `/claim <id>`. Finish: `/handoff <id> <path:line>`.
- Edit only directories you own (see PLAN.md). Contracts in `contracts/` are the interface: change one only after logging `ASK` or a DECISIONS line.
- "TEAM UPDATES" lines appear automatically. Act only if relevant to your task; otherwise ignore. Don't reply to them conversationally.
- Log format: `HH:MM @name EVENT text`. EVENT in DONE, BLOCKED, ASK @x, CLAIM-FILE, UNBLOCKS @x. One line, pointers not payloads.
- More than one round trip on anything means ask the human. Never loop with another agent.
- Commit small, `git pull --rebase` before push (hk.sh does this). Never force-push.
