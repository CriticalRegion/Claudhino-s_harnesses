# Hackathon Team Harness (v2)
Claude Code config for hackathons: demo-first rules, a deadline clock, cheap research agents, and git-based coordination for 2-4 people each running their own agent. Details in [GUIDE.md](GUIDE.md). What changed from v1: [GUIDE.md#changes-from-v1](GUIDE.md#9-changes-from-v1).

## Install (Claude Code >= 2.1.324, node, git, bash)
1. `bash hackathon-team-v2/install.sh /path/to/your-repo` - copies without overwriting your files (merges `.gitignore`, `CLAUDE.md`, `.mcp.json`, `.claude/settings.json`).
2. In your repo: commit and push. Each teammate clones, then runs `bash .hackathon/bin/hk.sh init <name>`.
3. `claude` (interactively once, accept the trust dialog and the ponytail plugin prompt), then `/mcp` to sign in to github and vercel.

## Flow
`/kickoff <brief>` -> `/slice` (repeat) -> `/cut` when behind -> `/ship` in the last hour.
Team: `/sync`, `/claim <id>`, `/handoff <id> <path:line>`. A clock hook injects time left; under 4h the agent polishes, under 1h it freezes features.

## What's in it, and why
| Piece | Purpose | Token effect |
|---|---|---|
| ponytail plugin (pinned v5.3.3) | Minimal code, reuse over build | Independent test (JetBrains): ~15% less code, ~10% lower cost; maker claims more |
| CLAUDE.md | Demo-first rules, fake-it policy, terse output | Short, always loaded |
| `scout` (Haiku) | Repo/doc lookups with context7 | Keeps big reads out of the main context, cheap model |
| `judge` (Sonnet) | Pre-submission critique in a real browser | One focused pass |
| context7 / playwright MCP (pinned) | Current library docs; verify the demo path | Fewer hallucinated-API loops, catches broken demos |
| github / vercel MCP | Commit, deploy, URL from chat | Fewer shell round-trips |
| read-deny rules | node_modules, build output, lockfiles, .env files | Prevents huge or secret reads |
| clock hook | Time left in context | ~20 tokens per prompt, only in the last 4h |
| `hk.sh` + state branch | Board / log / decisions on their own branch | Zero tokens when nothing changed |

## Test it
`bash hackathon-team-v2/tests/run.sh` - 82 end-to-end checks (installer, coordination incl. races and offline, clock, pre-push) against throwaway repos. Linux-tested; macOS paths are written for BSD tools but untested.
