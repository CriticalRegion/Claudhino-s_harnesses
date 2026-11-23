# Hackathon Hybrid Harness (v1)
Claude Code config for hackathon teams of 2-4, each running their own agent: everything in `hackathon-team-v3` (v3.1) **plus the best of [ECC](https://github.com/affaan-m/ECC)**, rewritten small, **plus fixes for every weakness a stress test found in v3.1**. New here: a safety **guard** that parses every shell command before it runs (no more `git -C . reset --hard` or `python -c rmtree` slipping past the allow list), **context / loop / budget warnings**, a **stop check** that makes the agent fix files it broke before ending a turn, a **handoff** that survives `/compact`, desktop **notifications**, a **statusline**, and `/verify`, `/checkpoint`, `/build-fix`, `/security-scan`, `/cost`. Details in [GUIDE.md](GUIDE.md) (new pieces: section 4 "New in the hybrid"; what changed and credits: section 9).

## Install (Claude Code >= 2.1.324, Node 16+, git, bash; on Windows, Git for Windows)
1. `bash hackathon-hybrid-v1/install.sh /path/to/your-repo` - copies without overwriting your files (merges `.gitignore`, `.gitattributes`, `CLAUDE.md`, `.mcp.json`, `.claude/settings.json`).
2. In your repo: commit and push. Each teammate clones, then runs `bash .hackathon/bin/hk.sh init <name>`.
3. `claude` (interactively once, accept the trust dialog and the ponytail plugin prompt), then `/mcp` to sign in to github and vercel.
4. Optional: `bash .hackathon/bin/hk.sh discord <forum-webhook-url> --global` (team feed), `HK_BUDGET_USD=20` in `.claude/settings.local.json` `env` (spend cap).
5. Check: `node .claude/hooks/hh.js check "git reset --hard"` prints `ask`; `node .claude/hooks/hh.js scan` runs the security checks.

## Flow
`/research <event URL>` (days before) -> `/kickoff <brief>` -> `/slice` (repeat; `/checkpoint` at milestones) -> `/verify` + `/handoff` -> `/demo-check` after deploys -> `/cut` when behind -> `/ship` in the last hour (runs `/verify full` and `/security-scan`) -> `/postmortem` after judging.
Team: `/sync`, `/claim <id>`, `/handoff <id> <path:line>`. Events arrive by themselves as `TEAM URGENT` (mid-task or waking you) and `TEAM UPDATES` (next prompt).

## What's in it, and why
| Piece | Purpose | Token effect |
|---|---|---|
| **guard** (`hh.js guard`, from ECC GateGuard) | Parses each command (quotes, `$(...)`, heredocs, `bash -c`, `sudo`/`env`/`timeout` wrappers) and asks your human before destructive git, recursive deletes, delete one-liners, hook bypasses, secret reads, remote code, unknown `npx` packages, config weakening and risky MCP actions; refuses them when nobody is there; always refuses board forging, human-only `hk.sh` commands and foreground dev servers (with the fix) | No tokens unless it fires; ~30 ms per call |
| **monitor** (`hh.js post`) | Context 55% / 68% warnings (compact at a milestone, not mid-edit), loop warning after 4 identical calls, spend budget | A line only when a threshold is crossed |
| **stop check** (`hh.js stop`) | Edited files must parse / typecheck before the turn ends; gives up after 2 tries | Saves the debug turns a broken file costs later |
| **handoff** + `/checkpoint` | Tasks, uncommitted files, commits and a 5-line note come back after `/compact`, `/clear` or a resume | Lets you compact early without losing the thread |
| statusline | `⏱ time left │ @you task │ modes │ demo │ ctx % │ $cost` | None (not in context) |
| notifications | Desktop notification when a turn over 45 s ends | None |
| `/verify` `/build-fix` (`build-fixer`) `/security-scan` `/cost` | Check before handoff; minimal-diff build fixes; pre-submission secret/injection scan; spend | One focused pass each |
| ponytail plugin (pinned v5.3.3) | Minimal code, reuse over build | Independent test (JetBrains): ~15% less code, ~10% lower cost |
| CLAUDE.md + `.hackathon/rules/` | Demo-first, safety, context rules; autonomous/solo/build-properly rules loaded only while active | Smaller than v3's CLAUDE.md |
| `scout` (Haiku) / `judge` (Sonnet) | Lookups; pre-submission critique in a real browser | Cheap model; one pass |
| context7 / playwright MCP (pinned), github / vercel MCP | Current docs; demo checks; deploys | Fewer hallucinated-API loops |
| clock hook | Time left in context | ~20 tokens per prompt, last 4h only |
| `hk.sh` + state branch | Board / log / decisions / cost on their own branch; events routed per person; works offline | Zero tokens when nothing changed; output capped |
| autonomous / solo mode | Agents work unattended until work runs out, with time and spend budgets, STUCK detection and an offline-proof kill switch | Stops itself when idle, stuck or over budget |
| `install.sh` | Non-destructive install, CRLF-safe | - |

## Commands at a glance
| Command | What it does |
|---|---|
| `/verify [quick\|full]` | Types/lint, build and tests (full), secret grep of the diff, diff skim; PASS/FAIL per step |
| `/checkpoint [note]` | wip commit + 5-line note so `/compact` is safe |
| `/build-fix [cmd]` | `build-fixer` agent gets a failing build passing with minimal diffs |
| `/security-scan` | Committed secrets, keys in code, hidden unicode, guard status, public board branch |
| `/cost` / `hk.sh cost` | Spend per teammate and team total |
| `hk.sh archive [--delete-remote]` | After the event (humans): keep the board, optionally delete the state branch from a public repo |
| `hk.sh auto on [2h]` / `off` / `--me` | Autonomous mode; `off` stops this machine instantly even offline |
| `/sync`, `/claim`, `/handoff`, `/demo-check`, `/research`, `/kickoff`, `/slice`, `/cut`, `/ship`, `/pitch`, `/postmortem`, `hk.sh solo`/`demo-first`/`note`/`discord`/`lesson` | As in v3 (GUIDE.md section 5) |

## Test it
`bash hackathon-hybrid-v1/tests/run.sh` - 404 end-to-end checks against throwaway repos (the 254 from v3.1 plus 150 for the guard's attack and everyday-command tables, the monitor, stop check, notifications, handoff, statusline, cost, security scan, offline kill switch, hung-network fail-fast, UTC times, unicode stripping and archive). GitHub Actions runs them on Linux, macOS (stock bash 3.2 + BSD awk) and Windows (Git Bash). The hybrid's new hooks have not yet been run in a live interactive Claude Code session; see GUIDE.md section 8.

Credits: guard, monitor, stop check, handoff, notification and statusline ideas from [ECC](https://github.com/affaan-m/ECC) by Affaan Mustafa (MIT), rewritten for this harness.
