Lean build (usage is the budget; `hk config set lean=off` turns this off):
- Scaffold with generators and CLI adds (`npx create-next-app`, `npx shadcn add`, `prisma init`, the starter in PLAN.md); never hand-write boilerplate.
- Edit, never rewrite whole files. Never paste code or file contents back into chat.
- Orient from `.hackathon/MAP.md` and the task card's `files:`; then grep and read line ranges. No Explore agent just to get oriented.
- Noisy commands: `set -o pipefail; <cmd> 2>&1 | tail -40` (or grep the error). If output was saved to a file, read only the lines you need.
- Two failed fixes of the same thing: escalate (build-fixer for build/type/lint, `deep` with a brief otherwise). Never a third blind try.
- Verify slices with `npm run check && npm run smoke`; walk the app with Playwright only in /hackathon:demo-check.
- context7: one topic per lookup, via `scout` when it's more than a quick check.
- Task boundary: after `hk done` you get CONTEXT OK (keep going in this session) or FRESH CONTEXT (do what it says). Don't /clear small sessions: re-orienting costs more than it saves.
- Dev server: start it as `npm run dev > .hackathon/dev.log 2>&1 & echo $! > .hackathon/dev.pid`; stop it with `kill $(cat .hackathon/dev.pid)`. Never `pkill -f` (it matches and kills your own shell).
