---
description: Walk the demo path in a real browser and log DEMO GREEN or DEMO RED for the team
argument-hint: [url]  (default: Live URL in PLAN.md)
---
1. URL: $ARGUMENTS, else the Live URL in `.hackathon/PLAN.md`. If neither loads, say so and stop.
2. With Playwright, walk every step of the PLAN.md demo path exactly as a judge would. Don't fix anything yet.
3. All steps work: `hk demo green "<url>"`. Any step fails: `hk demo red "step <n> <what broke> at <url>"` (one line, the first failure only).
4. Report in at most 3 lines. RED and the failing step is yours: fix it next; otherwise leave it to its owner (they're notified).
