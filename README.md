# Claudhino's harnesses

[![harness tests](https://github.com/CriticalRegion/Claudhino-s_harnesses/actions/workflows/harness-tests.yml/badge.svg)](https://github.com/CriticalRegion/Claudhino-s_harnesses/actions/workflows/harness-tests.yml)

Claude Code harnesses: drop-in project configs (rules, hooks, agents, slash commands, MCP servers) tuned for a specific kind of work. Each harness lives in its own folder and is self-contained.

## Current: [`hackathon-team-v4`](hackathon-team-v4/) (Claude Code plugin)

A Claude Code plugin for hackathon teams of 1-4 people, each running their own agent. It keeps agents on the demo path, watches the clock, and coordinates the team through git, so agents share **events, not conversation**. It's **toggleable per project**: pause it instantly, or turn it off and Claude is normal again.

**What it does**
- **Setup interview per event** (`/hackathon:setup`): the event, deadline, judging criteria and weights, team; a profile (**sprint**, **crunch**, **careful**) and any of ~25 toggles, shared by the whole team through the board.
- **Opus ideation, you pick** (`/hackathon:kickoff`): 8-10 ideas from different angles, web-checked for "already exists", scored by a strict Opus `judge` on the weighted criteria; you choose from the top 3; then a lean plan and the first task. **Switchable**: already have an idea? `hk config set ideation=off` (setup asks) and kickoff just plans yours. `/hackathon:pivot` switches to a runner-up later.
- **Lean builds** (switchable): a fresh context per task, task cards and a generated code map instead of exploring, smoke checks instead of a browser walk per slice, a flail guard that escalates after two identical failures, capped tool output, and usage per task on every DONE line.
- **Demo-first rules, switchable** to build-it-properly; a **deadline clock** that moves agents into polish and feature freeze; rules injected only when active (never in your CLAUDE.md).
- **Team board on its own git branch**: claims with one winner, dependencies, offline queueing; it never touches your code.
- **Live events**: a teammate's `DONE` on a task you depend on, an `ASK` to you, or a contract change reaches your agent **mid-task** or **wakes it when idle**, as one line. Loop guard, collision guard, stale-claim takeover, contract alerts.
- **Autonomous mode** and **solo mode** (humans switch them on; a kill switch that works offline); a **`deep`** agent hands hard problems to Opus.
- **Guard, monitor, stop check, handoff across `/compact`, status line, security scan**, from the team's hybrid-v1, each a setting (guard and stop check on in the careful profile).
- **Discord feed** (one forum post per hackathon, under each person's name), **usage log** by model and per teammate, **research** before and **postmortem lessons** after every event.
- **Runs on** Linux, macOS and Windows (Git Bash). 583 end-to-end tests in CI on all three; setup, kickoff, pause/resume and a plugin-less session checked live in Claude Code.

**Install once per machine**, in Claude Code:
```
/plugin marketplace add CriticalRegion/Claudhino-s_harnesses
/plugin install hackathon@claudhino
```
**Every hackathon**, in your project: `/hackathon:setup`, then `/hackathon:kickoff`. Teammates install the plugin and run `/hackathon:setup` (it only asks their name and Discord).

**Set up in one paste** (for a teammate's agent, or if you'd rather not type the commands):

````text
Set up the Claudhino hackathon harness (v4 plugin) for this project.
1. If the /hackathon:setup command isn't available, tell me to run these two commands myself in
   Claude Code and stop:  /plugin marketplace add CriticalRegion/Claudhino-s_harnesses
                          /plugin install hackathon@claudhino
2. Otherwise run /hackathon:setup and follow its interview with me. Ask me every question it asks;
   don't assume answers. Don't turn on autonomous or solo mode.
````

Short docs: [hackathon-team-v4/README.md](hackathon-team-v4/README.md). Full guide (every setting, tuning, troubleshooting, what was tested): [hackathon-team-v4/GUIDE.md](hackathon-team-v4/GUIDE.md).

## Legacy: [`hackathon-team-v3`](hackathon-team-v3/)

The same harness as files copied into your repo (`install.sh`), at v3.1. Still works and is still tested in CI, but it's always on in a project (no pause/off), has no setup interview, and lacks the guard, monitor and stop check. A v3 project upgrades to v4 with `/hackathon:setup` (it offers to remove the copied files). Docs: [hackathon-team-v3/README.md](hackathon-team-v3/README.md).

## Licence
MIT, see [LICENSE](LICENSE). Parts of v4 are adapted from ECC (MIT); see [notices](hackathon-team-v4/THIRD_PARTY_NOTICES.md).

## Deprecated

Kept for reference only; they get no fixes. Use v4.

| Folder | Why it's deprecated |
|---|---|
| [`hackathon-team-v2`](hackathon-team-v2/) | Superseded by v3 and v4 (event notifications, macOS/Windows fixes, the plugin). A v2 board upgrades in place: `/hackathon:setup` in the project. |
| [`hackathon-team-v1`](hackathon-team-v1/) | Known bugs: board commands push unfinished code to main and report success when offline, and its `cp -r` install overwrites your README and `.gitignore` ([details](hackathon-team-v2/GUIDE.md#9-changes-from-v1)). |

## Conventions for adding a harness or a variant

- One folder per harness, named `<purpose>-<variant>-v<N>`, e.g. `hackathon-solo-v1`, `hackathon-team-v5`. Plugins are listed in `.claude-plugin/marketplace.json` (marketplace `claudhino`). Don't edit an old version in place when making a breaking change; add a new folder and move the old one to the Deprecated table.
- Each folder contains the files exactly as they should land in a user's repo (`CLAUDE.md`, `.claude/`, `.mcp.json`, ...), plus:
  - `README.md`: install in under 20 lines.
  - `GUIDE.md`: what every piece does, why, how to tune it, troubleshooting, and known limits.
  - `install.sh`: a non-destructive installer.
- State what was actually tested and how. Keep claims about token savings tied to a source.
- Tests for a harness live in its `tests/run.sh`; add it to `.github/workflows/harness-tests.yml` so it runs on Linux, macOS and Windows.
- Update this README in the same commit.
