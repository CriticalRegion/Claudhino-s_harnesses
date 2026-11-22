# Hackathon Team Harness (v1)
Copy this folder's contents into the root of your hackathon repo: `cp -r hackathon-team-v1/. your-repo/`. Details in [GUIDE.md](GUIDE.md).

## One-time install (Claude Code >= 2.1.290)
1. `claude` in the repo, accept the project plugin prompt. If ponytail isn't active: `/plugin marketplace add DietrichGebert/ponytail` then `/plugin install ponytail@ponytail`. Needs `node` on PATH.
2. Authenticate remote MCPs when prompted: `/mcp` -> github, vercel.
3. Optional install of extras from your own skill list: `frontend-design` (UI polish), `dataviz` (charts), `pptx`/`docs` (pitch deck) - these are already available in claude.ai.

## Flow
`/kickoff <brief>` -> `/slice` (repeat) -> `/cut` when behind -> `/ship` in the last hour.
A clock hook injects time-left, shifting the agent into polish then freeze mode automatically.

## What's in it, and why
| Piece | Purpose | Token effect |
|---|---|---|
| ponytail | Minimal code, reuse over build | Fewer output tokens; independent benchmarks (JetBrains) measured ~15% less code, ~10% lower cost, below the headline 54% |
| CLAUDE.md | Demo-first rules, fake-it policy, terse output | Short, always-loaded, no fluff |
| `scout` (Haiku) | Repo/doc lookups | Keeps big reads out of main context, cheap model |
| context7 MCP | Current library docs | Fewer hallucinated-API debug loops |
| playwright MCP | Verify demo path in a real browser | Catches broken demos early |
| github / vercel MCP | Commit, deploy, URL from chat | Replaces many shell round-trips |
| deny rules | node_modules, lockfiles, build output, .env | Prevents huge accidental reads |
| clock hook | Time left in context | ~20 tokens, enforces scope |
| `judge` agent | Pre-submission critique vs criteria | One focused pass |

## Tuning
- Ponytail can feel aggressive on unfamiliar code; use `/ponytail-help` for levels and `stop ponytail` for polish-heavy UI work.
- Switch `"model"` to `opus` for one hard problem, then back.
- Remove `vercel`/`github` from `.mcp.json` if you deploy another way; each MCP adds tool-schema tokens.

## Team of several (agents coordinate via git)
Each person: `bash .hackathon/bin/hk.sh init <name>`. Then `/sync`, `/claim <id>`, `/handoff <id> <path:line>`. Board, log and decisions live in `.hackathon/`. Full details in GUIDE.md.
