---
description: Night shift - check the Done-when list strictly, then end the shift (goal met) or add the tasks that close the gaps
---
You claimed `goal-N`. Be strict: an item passes only with evidence you produced just now.
1. `git switch main && git pull --rebase --autostash`, then `/hackathon:verify full`.
2. For each `Done when` item in `.hackathon/state/NIGHT.md`, check it concretely: run the command or test, hit the endpoint, or walk the step in the browser (`/hackathon:demo-check` for the demo path). One line each: `- PASS <item> - <evidence>` or `- FAIL <item> - <what happened>`.
3. Before calling anything met, give the `critic` agent the PASS lines and their evidence and ask it to challenge them; anything it disproves becomes a FAIL.
4. Write `.hackathon/notes/goal-check.md`: the PASS/FAIL lines, then, if anything failed, `## New tasks` with 1-6 small tasks `- <id>: <what, in which files> [after x]` that close the gaps (new ids).
5. All PASS: `hk goal met .hackathon/notes/goal-check.md` (the shift ends and writes the morning report). Otherwise: `hk goal gaps .hackathon/notes/goal-check.md` (the new tasks go on the board and wake the other agents; the number of goal checks is capped).
