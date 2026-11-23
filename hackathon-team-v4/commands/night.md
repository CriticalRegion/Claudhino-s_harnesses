---
description: Plan a night shift - agents build, critique each other's work and merge toward a goal while the team is away
argument-hint: <the goal, e.g. "build v5: offline mode and the leaderboard">
---
Goal from the human: $ARGUMENTS
You plan the shift; the human starts it. Planning quality decides how the night goes, so think hard (suggest /model opus for this if they're on Sonnet).
1. Read `.hackathon/PLAN.md`, the board (`hk board`), the last 30 LOG lines, and the repo layout (ask `scout` for anything you need from the code). If the goal is vague, ask the human at most 3 short questions; otherwise state your assumptions.
2. Write `.hackathon/NIGHT.md` with exactly these sections:
   - `## Goal`: 1-3 lines.
   - `## Done when`: 3-8 checkbox items (`- [ ] ...`), each verifiable by a command, a test, or a concrete demo step ("`npm test` passes", "POST /api/scores returns 201 and the leaderboard shows it", "works offline: reload with the network off shows cached scores"). This list is the contract: agents stop when it passes.
   - `## Out of scope`: what not to touch tonight.
   - `## Constraints`: stack decisions, files or contracts not to change, external services allowed (no new paid services or secrets unless the human set them up).
   - `## Tasks`: 4-12 lines `- <id>: <what, in which files> [after a,b]`, each small enough to build and review in one go (under ~300 changed lines), as independent as possible so 2-3 agents can work in parallel, ordered so contracts/schema come first. No owners: agents claim them.
3. Show the plan to the human in under 25 lines and adjust what they ask for. Commit `.hackathon/NIGHT.md` and push.
4. Tell them how to start it, in their own terminal (an agent can't start it):
   `.hackathon/bin/hk night start --until 07:00 --budget 30`
   - `--until`: a time or a duration (default 8h). `--budget`: US dollars for the whole team (from the status lines), optional.
   - Every teammate who wants their agent to join leaves Claude Code running in this project (plugged in, sleep off: `caffeinate -is claude` on macOS), or runs it in a container/VM. With nobody else up, one agent reviews its own work through a fresh critic agent.
   - In the morning: `hk night report`. Stop early: `hk night stop`.
