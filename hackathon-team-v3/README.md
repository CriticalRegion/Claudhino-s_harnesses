# Hackathon Team Harness (v3)
Claude Code config for hackathons: demo-first rules, a deadline clock, cheap research agents, and git-based coordination for 2-4 people each running their own agent. New in v3: **event notifications**. A teammate's DONE on a task you depend on, an ASK to you, or a contract change reaches your agent mid-task or wakes it when idle, as one line, with no agent-to-agent chat. Details in [GUIDE.md](GUIDE.md), changes in [section 9](GUIDE.md#9-changes-from-v2).

## Install (Claude Code >= 2.1.324, node, git, bash; on Windows, Git for Windows)
1. `bash hackathon-team-v3/install.sh /path/to/your-repo` - copies without overwriting your files (merges `.gitignore`, `CLAUDE.md`, `.mcp.json`, `.claude/settings.json`).
2. In your repo: commit and push. Each teammate clones, then runs `bash .hackathon/bin/hk.sh init <name>`.
3. `claude` (interactively once, accept the trust dialog and the ponytail plugin prompt), then `/mcp` to sign in to github and vercel.
4. Optional, once per machine: make a Discord **Forum** channel with a webhook and run `bash .hackathon/bin/hk.sh discord <webhook-url> --global`. Each project then gets its own forum post automatically.

Built for Linux, macOS (including the stock bash 3.2 and BSD tools) and Windows (Git Bash, which Claude Code uses for hooks there); CI runs the tests on all three. Scripts are kept LF-only so Windows CRLF checkouts can't break them.

## Flow
`/research <event URL>` (days before) -> `/kickoff <brief>` -> `/slice` (repeat) -> `/demo-check` after deploys -> `/cut` when behind -> `/ship` in the last hour -> `/postmortem` after judging (lessons every future `/kickoff` reads).
Team: `/sync`, `/claim <id>`, `/handoff <id> <path:line>`. Events arrive by themselves as `TEAM URGENT` (mid-task or waking you) and `TEAM UPDATES` (next prompt).

## What's in it, and why
| Piece | Purpose | Token effect |
|---|---|---|
| ponytail plugin (pinned v5.3.3) | Minimal code, reuse over build | Independent test (JetBrains): ~15% less code, ~10% lower cost; maker claims more |
| CLAUDE.md | Demo-first rules (toggleable to build-it-properly), how to react to events | Short, always loaded |
| `scout` (Haiku) / `judge` (Sonnet) | Repo/doc lookups; pre-submission critique in a real browser | Cheap model; one focused pass |
| context7 / playwright MCP (pinned) | Current library docs; verify the demo path | Fewer hallucinated-API loops, catches broken demos |
| github / vercel MCP | Commit, deploy, URL from chat | Fewer shell round-trips |
| read-deny rules | node_modules, build output, lockfiles, .env files | Prevents huge or secret reads |
| clock hook | Time left in context | ~20 tokens per prompt, only in the last 4h |
| `hk.sh` + state branch | Board / log / decisions on their own branch, never touching your code | Zero tokens when nothing changed |
| event routing + hooks | Urgent-for-you events mid-task (`PostToolUse`) or by waking you (`asyncRewake`); FYI at the next prompt | ~20-40 tokens per relevant event, capped at 6 wakes/hour |
| guards | One ASK/ANSWER round trip then ESCALATE to humans; collision warning before editing a teammate's file; stale-claim takeover; contract-change alerts | Prevents agent loops and wasted work |
| Discord webhook (optional) | Humans follow every event: one forum post per project, created automatically, under each person's name | No agent tokens |
| autonomous mode | `hk.sh auto on [2h]` (humans only): agents approve their own prompts except destructive or mode-changing commands (deny list still applies), never ask, keep going until work runs out; team-wide kill switch `hk.sh auto off` | Stops itself when idle or stuck |
| solo mode | `hk.sh solo @name`: one agent finishes alone with free rein; everyone else is muted | No team chatter in the endgame |
| `/demo-check` | Walks the demo path in a browser after deploys, logs DEMO GREEN/RED | One focused pass |
| `install.sh` | Non-destructive install: merges `.gitignore`, `.gitattributes`, `CLAUDE.md`, `.mcp.json`, `settings.json`; strips CRLF from scripts | - |

## Commands at a glance
| Command | What it does |
|---|---|
| `hk.sh init <name>` | Join the team board (once per clone) |
| `/sync` | Refresh the board and pull code; shows what's urgent for you and STALE tasks |
| `/claim <id> [--take]` | Take a task; `--take` takes over a stale one |
| `/handoff <id> <path:line>` | Push code, mark done; teammates who depend on it are notified |
| `hk.sh add <id> <ref> --after <ids>` | Add a task and what it depends on |
| `hk.sh log "ASK @x: ..."` / `"ANSWER @x: ..."` / `"BLOCKED ..."` / `"CLAIM-FILE <path>"` | Post an event |
| `hk.sh note "@name ..."` | A human's note to someone's agent |
| `hk.sh demo green\|red "..."` | Demo-path health (used by `/demo-check`) |
| `hk.sh discord <url> [--global]` / `off` / `test` / `status` | Post your events to Discord (`--global`: every project on this machine) |
| `hk.sh auto on [2h] [--me]` / `off` / `status` | Autonomous mode for the team (or just you) |
| `hk.sh solo @name [2h]` / `solo off` | One agent finishes alone; others muted |
| `hk.sh demo-first off` / `on` [`--me`] | Switch the team between demo-first and build-it-properly rules |
| `/research <event URL>` | Pre-event brief: sponsors' newest tech, judges, criteria, tracks, past winners, 3 winning angles |
| `/postmortem` / `hk.sh lesson "..."` / `hk.sh lessons` | Save lessons after an event; every future `/kickoff` reads them |

## Test it
`bash hackathon-team-v3/tests/run.sh` - 255 end-to-end checks against throwaway repos: everything from v2 plus routing, delivery, wake-ups, guards, Discord via a local fake webhook, v2-board upgrade, CRLF and Windows-path handling, autonomous and solo mode, including the autonomous safety rules and the lessons memory. GitHub Actions runs them on Linux, macOS (stock bash 3.2 + BSD awk) and Windows (Git Bash, CRLF checkout) on every push and PR. Wake-ups, mid-task delivery, the collision guard, the loop guard, autonomous mode, solo mode and the kill switch were also verified in live interactive Claude Code sessions on Linux.
