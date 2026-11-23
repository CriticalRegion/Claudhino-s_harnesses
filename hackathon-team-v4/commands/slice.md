---
description: Build the next piece of the plan (a thin demo slice, or the full feature when demo-first is off)
---
Read `.hackathon/PLAN.md`. Work on the task you hold (`hk status`), else the earliest unfinished demo-path step; in a team, if no board task covers it, add one first (`hk add <id> <ref> --after <deps>`) and claim it.
- Holding `t0-scaffold`: scaffold the stack, add a fast `check` script to package.json (typecheck and/or lint, under ~30s, not a full build) so the pre-push hook can keep main demoable, deploy hello-world (Vercel MCP or CLI), put the live URL in PLAN.md, run `/hackathon:demo-check`, then `/hackathon:handoff t0-scaffold <path:line>`.
- Demo-first (default): implement the smallest end-to-end version; fake what judges can't see and tag it with a `FAKE:` comment. DEMO-FIRST OFF: implement the complete feature with error handling and tests for its logic, and replace any `FAKE:` stubs it touches.
If the dev server isn't running, start it in the background with the dev command from PLAN.md. Verify with Playwright on the running app. Commit. Report: what works, what's next. At most 5 lines.
