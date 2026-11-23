---
description: Switch to a runner-up idea from IDEAS.md and re-plan the time left, on Opus
argument-hint: [your pick]
model: opus
---
Input: $ARGUMENTS
1. Read `.hackathon/IDEAS.md`, `.hackathon/PLAN.md`, `hk clock` and `hk board`. No pick in the input: show the runners-up with how much of the current work each could reuse and what's realistic in the time left, then STOP and ask the human to reply `/hackathon:pivot <pick>`. Never pick for them.
2. With a pick: rewrite PLAN.md's Plan section (lean), move abandoned work to the Cut list, `hk decide "PIVOT to <idea>: <why>"`, release or re-scope board tasks (`hk release`, `hk add`), commit. Report in at most 5 lines.
