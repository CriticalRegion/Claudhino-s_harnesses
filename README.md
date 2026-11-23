# Claudhino's harnesses

[![harness tests](https://github.com/CriticalRegion/Claudhino-s_harnesses/actions/workflows/harness-tests.yml/badge.svg)](https://github.com/CriticalRegion/Claudhino-s_harnesses/actions/workflows/harness-tests.yml)

Claude Code harnesses: drop-in project configs (rules, hooks, agents, slash commands, MCP servers) tuned for a specific kind of work. Each harness lives in its own folder and is self-contained.

## Current: [`hackathon-team-v3`](hackathon-team-v3/)

A Claude Code setup for hackathon teams of 2-4 people, each running their own agent. It keeps agents on the demo path, watches the clock, and coordinates the team through git, so agents share **events, not conversation**.

**What it does**
- **Demo-first rules:** build only the demo path, vertical slice first, fake what judges can't see (tagged `FAKE:` so the pitch stays honest), deploy early.
- **Smarter kickoff:** `/kickoff` generates 5 ideas, drops ones that already exist, scores the rest on originality, real-world problem, sponsor tech and demo-to-effort, then scaffolds, deploys and splits the work into board tasks with dependencies.
- **Deadline clock:** time left is injected into context; under 4h the agent polishes, under 1h it freezes features.
- **Team board on its own git branch:** claim tasks (the remote is the lock, so simultaneous claims have exactly one winner), log events, record decisions. It never pushes, pulls or rebases your code, and it works offline (queued, pushed later).
- **Event notifications:** a teammate's `DONE` on a task you depend on, an `ASK` to you, or a contract change reaches your agent **mid-task** or **wakes it when idle**, as one line (~20-40 tokens). Everything else waits for your next prompt.
- **Guards:** one ASK/ANSWER round trip, then it escalates to the humans; the first edit of a teammate's claimed or owned file is refused with a warning; stale claims can be taken over; contract changes are announced; pushes to main must pass `npm run check` and a Python syntax check.
- **Autonomous mode** (`hk.sh auto on 2h`): agents approve their own prompts (the safety deny list still applies), never stop to ask, and keep working through the board until the work runs out, with a time budget, stuck detection and a team-wide kill switch (`hk.sh auto off`).
- **Solo mode** (`hk.sh solo @alice`): for the endgame, one agent finishes alone with free rein over the repo while everyone else's agent is muted.
- **Discord feed:** set a Forum channel's webhook once per machine (`hk.sh discord <url> --global`); every hackathon then gets its own forum post automatically, and each event appears as one line with an emoji, under the teammate's name. No bot, no per-event setup.
- **Demo health:** `/demo-check` walks the demo path in a real browser after deploys and logs `DEMO GREEN` / `DEMO RED` for the team; the `judge` agent scores the demo against the judging criteria before submission.
- **Token-lean by design:** ponytail (minimal code), a Haiku `scout` for lookups, terse rules, zero tokens when nothing changed, read-deny rules for `node_modules`, build output, lockfiles and `.env` files.
- **Safe install:** `install.sh` merges into your repo (`.gitignore`, `.gitattributes`, `CLAUDE.md`, `.mcp.json`, settings) and never overwrites your files; pinned plugin and MCP versions.
- **Runs on** Linux, macOS (stock bash 3.2 and BSD tools) and Windows (Git Bash); 209 end-to-end tests run in CI on all three, and the event, autonomous and solo features were verified in live Claude Code sessions.

**Set up in one paste**

Paste this into Claude Code (or any coding agent) opened in your project folder. It works for the person setting up the project and for teammates joining it.

````text
Set up the Claudhino hackathon harness (v3) in this project. Do the steps in order and ask me
for anything you need; don't guess names, URLs or dates.

1. Check this folder is a git repo with at least one commit. If not, stop and tell me.
2. If .hackathon/bin/hk.sh already exists, a teammate already installed the harness: skip to step 5.
3. Clone https://github.com/CriticalRegion/Claudhino-s_harnesses into a temporary folder outside
   this repo, then run: bash <that folder>/hackathon-team-v3/install.sh "$(pwd)"
   Show me the installer's summary (added / merged / skipped files).
4. Commit the harness files ("hackathon harness"). Ask me before pushing; push only if I say yes.
5. Ask me for my team handle (short, lowercase, e.g. "alice"), then run:
   bash .hackathon/bin/hk.sh init <handle>
   (this creates or joins the team board, a separate "hackathon-state" branch on the remote; it never pushes code)
6. Ask me for the hackathon deadline in local time. If .hackathon/deadline still contains
   YYYY-MM-DD, write it as YYYY-MM-DDTHH:MM (nothing else in the file) and commit it.
7. Discord (optional): ask me whether I have a Discord webhook URL for a Forum channel.
   If I give you one, run: bash .hackathon/bin/hk.sh discord <url> --global
   Treat the URL as a secret: never write it into any file in this repo, a commit, or a message.
   Ask me before running: bash .hackathon/bin/hk.sh discord test   (it posts to the channel).
8. Run bash .hackathon/bin/hk.sh sync and bash .hackathon/bin/hk.sh auto status and show me the output.
9. Finish with what I still have to do myself:
   - restart Claude Code here and accept the trust dialog and the ponytail plugin prompt,
   - run /mcp and sign in to github and vercel,
   - if I'm the first on the team: share the repo, and DM teammates the Discord webhook URL,
   - next step: /kickoff <brief, theme, deadline, team size>.
Don't turn on autonomous or solo mode, and don't change any other settings.
````

**Manual install instead:** `git clone https://github.com/CriticalRegion/Claudhino-s_harnesses && bash Claudhino-s_harnesses/hackathon-team-v3/install.sh /path/to/your-repo`, commit and push, then each teammate runs `bash .hackathon/bin/hk.sh init <name>`, starts `claude` once to accept the trust dialog, and signs in to GitHub and Vercel with `/mcp`.

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
