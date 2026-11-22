# Hackathon Team Harness (v3)
Claude Code config for hackathons: demo-first rules, a deadline clock, cheap research agents, and git-based coordination for 2-4 people each running their own agent. New in v3: **event notifications**. A teammate's DONE on a task you depend on, an ASK to you, or a contract change reaches your agent mid-task or wakes it when idle, as one line, with no agent-to-agent chat. Details in [GUIDE.md](GUIDE.md), changes in [section 9](GUIDE.md#9-changes-from-v2).

## Install (Claude Code >= 2.1.324, node, git, bash)
1. `bash hackathon-team-v3/install.sh /path/to/your-repo` - copies without overwriting your files (merges `.gitignore`, `CLAUDE.md`, `.mcp.json`, `.claude/settings.json`).
2. In your repo: commit and push. Each teammate clones, then runs `bash .hackathon/bin/hk.sh init <name>`.
3. `claude` (interactively once, accept the trust dialog and the ponytail plugin prompt), then `/mcp` to sign in to github and vercel.
4. Optional: post your events to Discord with `bash .hackathon/bin/hk.sh discord <webhook-url>`.

## Flow
`/kickoff <brief>` -> `/slice` (repeat) -> `/demo-check` after deploys -> `/cut` when behind -> `/ship` in the last hour.
Team: `/sync`, `/claim <id>`, `/handoff <id> <path:line>`. Events arrive by themselves as `TEAM URGENT` (mid-task or waking you) and `TEAM UPDATES` (next prompt).

## What's in it, and why
| Piece | Purpose | Token effect |
|---|---|---|
| ponytail plugin (pinned v5.3.3) | Minimal code, reuse over build | Independent test (JetBrains): ~15% less code, ~10% lower cost; maker claims more |
| CLAUDE.md | Demo-first rules, fake-it policy, how to react to events | Short, always loaded |
| `scout` (Haiku) / `judge` (Sonnet) | Repo/doc lookups; pre-submission critique in a real browser | Cheap model; one focused pass |
| context7 / playwright MCP (pinned) | Current library docs; verify the demo path | Fewer hallucinated-API loops, catches broken demos |
| github / vercel MCP | Commit, deploy, URL from chat | Fewer shell round-trips |
| read-deny rules | node_modules, build output, lockfiles, .env files | Prevents huge or secret reads |
| clock hook | Time left in context | ~20 tokens per prompt, only in the last 4h |
| `hk.sh` + state branch | Board / log / decisions on their own branch, never touching your code | Zero tokens when nothing changed |
| event routing + hooks | Urgent-for-you events mid-task (`PostToolUse`) or by waking you (`asyncRewake`); FYI at the next prompt | ~20-40 tokens per relevant event, capped at 6 wakes/hour |
| guards | One ASK/ANSWER round trip then ESCALATE to humans; collision warning before editing a teammate's file; stale-claim takeover; contract-change alerts | Prevents agent loops and wasted work |
| Discord webhook (optional) | Humans follow every event in a channel | No agent tokens |

## Test it
`bash hackathon-team-v3/tests/run.sh` - 144 end-to-end checks against throwaway repos (everything from v2 plus routing, delivery, wake-ups, guards, Discord via a local fake webhook, v2-board upgrade). Linux-tested; wake-ups, mid-task delivery and the collision guard were also verified in a live interactive Claude Code session.
