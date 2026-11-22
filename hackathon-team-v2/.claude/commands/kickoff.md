---
description: Turn the hackathon brief into PLAN.md and a deployed skeleton
argument-hint: <brief, theme, deadline, team size>
---
Brief: $ARGUMENTS
1. Ask at most 3 questions only if the brief truly lacks: deadline, judging criteria, team skills. Otherwise assume and state assumptions.
2. Pick ONE idea with the best demo-to-effort ratio against the judging criteria. Name 2 runners-up in one line each.
3. Fill `.hackathon/PLAN.md` (every field). Write the deadline to `.hackathon/deadline` as local time `YYYY-MM-DDTHH:MM`, nothing else in the file.
4. Scaffold the stack. Add a fast `check` script to package.json (typecheck and/or lint, under ~30s; not a full build) so the pre-push hook can keep main demoable. Commit, deploy hello-world (Vercel MCP or CLI), put the live URL in PLAN.md.
5. Team of 2+: create `contracts/` with the shared interfaces (API types/routes, schema) as stubs, fill the Owners line in PLAN.md (one directory per person), and add one board task per slice: `bash .hackathon/bin/hk.sh add <id> <dir or contract file>`. Commit and push code.
6. Report the live URL and the task ids. Stop there.
