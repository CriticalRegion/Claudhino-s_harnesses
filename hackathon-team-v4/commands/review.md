---
description: Night shift - review a teammate's task branch with a fresh critic and record the verdict
argument-hint: <task-id>
---
Task: $ARGUMENTS
1. `hk brief $ARGUMENTS`: task, branch, round, the builder's note, the previous review, the Done-when list.
2. Check out the branch next to your work without touching it: `git fetch -q origin`, then `git worktree add --detach .hackathon/rev/$ARGUMENTS origin/<branch>` (if it exists already: `git -C .hackathon/rev/$ARGUMENTS checkout -q --detach origin/<branch>`).
3. Give the `critic` agent the brief and the worktree path; wait for its verdict. Don't review it again yourself (that doubles the tokens); only sanity-check that each MUST has a path:line and a fix.
4. Write the critic's findings to `.hackathon/notes/review-$ARGUMENTS.md` (numbered MUST/SHOULD/NIT lines, then the Checks line).
5. `hk verdict $ARGUMENTS approve|changes|block .hackathon/notes/review-$ARGUMENTS.md` (approve only with no MUST). The builder's agent is notified.
6. `git worktree remove .hackathon/rev/$ARGUMENTS` and go back to your own work. Report in one line.
