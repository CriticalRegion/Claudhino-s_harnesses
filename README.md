# Claudhino's harnesses

[![harness tests](https://github.com/CriticalRegion/Claudhino-s_harnesses/actions/workflows/harness-tests.yml/badge.svg)](https://github.com/CriticalRegion/Claudhino-s_harnesses/actions/workflows/harness-tests.yml)

Claude Code harnesses: drop-in project configs (rules, hooks, agents, slash commands, MCP servers) tuned for a specific kind of work. Each harness lives in its own folder and is self-contained.

## Current: [`hackathon-team-v3`](hackathon-team-v3/)

A Claude Code setup for hackathon teams of 2-4 people, each running their own agent. It keeps agents on the demo path, watches the clock, and coordinates the team through git, so agents share **events, not conversation**.

**What it does**
- **Demo-first rules:** build only the demo path, vertical slice first, fake what judges can't see (tagged `FAKE:` so the pitch stays honest), deploy early.
- **Deadline clock:** time left is injected into context; under 4h the agent polishes, under 1h it freezes features.
- **Team board on its own git branch:** claim tasks (the remote is the lock, so simultaneous claims have exactly one winner), log events, record decisions. It never pushes, pulls or rebases your code.
- **Event notifications:** a teammate's `DONE` on a task you depend on, an `ASK` to you, or a contract change reaches your agent **mid-task** or **wakes it when idle**, as one line (~20-40 tokens). Everything else waits for your next prompt.
- **Guards:** one ASK/ANSWER round trip, then it escalates to the humans; a warning before editing a teammate's file; stale-claim takeover; contract-change alerts.
- **Autonomous mode** (`hk.sh auto on 2h`): agents approve their own prompts (the safety deny list still applies), never stop to ask, and keep working through the board until the work runs out, with a time budget and a team-wide kill switch (`hk.sh auto off`).
- **Solo mode** (`hk.sh solo @alice`): for the endgame, one agent finishes alone with free rein over the repo while everyone else's agent is muted.
- **Extras:** `/demo-check` (browser walk of the demo path after deploys), an optional Discord webhook so humans can follow every event, Haiku `scout` and Sonnet `judge` agents, pinned context7 / Playwright / GitHub / Vercel MCP servers, and read-deny rules for secrets and build output.
- **Runs on** Linux, macOS (stock bash 3.2 and BSD tools) and Windows (Git Bash).

**Quick start**
```bash
git clone https://github.com/CriticalRegion/Claudhino-s_harnesses
bash Claudhino-s_harnesses/hackathon-team-v3/install.sh /path/to/your-repo   # merges, never overwrites
```
Then, in your repo:
1. Commit and push the harness files.
2. Each teammate runs `bash .hackathon/bin/hk.sh init <name>` once.
3. Start `claude` once interactively to accept the trust dialog, then `/mcp` to sign in to GitHub and Vercel.

**Flow:** `/kickoff <brief>` → `/slice` (repeat) → `/demo-check` after deploys → `/cut` when behind → `/ship` in the last hour. Team: `/sync`, `/claim <id>`, `/handoff <id> <path:line>`.

Short docs: [hackathon-team-v3/README.md](hackathon-team-v3/README.md). Full guide (every piece, tuning, troubleshooting, what was tested): [hackathon-team-v3/GUIDE.md](hackathon-team-v3/GUIDE.md).

## Deprecated

Kept for reference only; they get no fixes. Use v3.

| Folder | Why it's deprecated |
|---|---|
| [`hackathon-team-v2`](hackathon-team-v2/) | Superseded by v3, which adds event notifications and macOS/Windows fixes. A v2 board upgrades in place: install v3 over it and run `hk.sh sync`. |
| [`hackathon-team-v1`](hackathon-team-v1/) | Known bugs: board commands push unfinished code to main and report success when offline, and its `cp -r` install overwrites your README and `.gitignore` ([details](hackathon-team-v2/GUIDE.md#9-changes-from-v1)). |

## Conventions for adding a harness or a variant

- One folder per harness, named `<purpose>-<variant>-v<N>`, e.g. `hackathon-solo-v1`, `hackathon-team-v4`. Don't edit an old version in place when making a breaking change; add a new folder and move the old one to the Deprecated table.
- Each folder contains the files exactly as they should land in a user's repo (`CLAUDE.md`, `.claude/`, `.mcp.json`, ...), plus:
  - `README.md`: install in under 20 lines.
  - `GUIDE.md`: what every piece does, why, how to tune it, troubleshooting, and known limits.
  - `install.sh`: a non-destructive installer.
- State what was actually tested and how. Keep claims about token savings tied to a source.
- Tests for a harness live in its `tests/run.sh`; add it to `.github/workflows/harness-tests.yml` so it runs on Linux, macOS and Windows.
- Update this README in the same commit.
