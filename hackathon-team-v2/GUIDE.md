# Hackathon Team Harness (v2): full guide

A Claude Code project configuration for hackathons. It spends fewer tokens, steers the agent toward a working, demoable product before the deadline, and lets 2-4 people (each with their own agent) split work without stepping on each other.

---

## 1. What it is

```
hackathon-team-v2/
├── install.sh                 # Non-destructive installer (not copied into your repo)
├── tests/run.sh               # End-to-end tests (not copied)
├── README.md, GUIDE.md        # Docs (not copied)
├── CLAUDE.md                  # Always-loaded rules: demo-first, fake-it policy, terse output, team protocol
├── .mcp.json                  # MCP servers: context7, playwright (pinned), github, vercel
├── .gitignore                 # Lines merged into yours: per-clone harness state, .env files, build output
├── .githooks/pre-push         # Pushes to main/master must pass `npm run check` (if defined)
├── .hackathon/
│   ├── PLAN.md                # Pitch, owners, demo path, URLs, milestones, cut list (filled by /kickoff)
│   ├── deadline               # Local time YYYY-MM-DDTHH:MM; drives the clock hook
│   └── bin/hk.sh              # Team coordination: init/sync/peek/claim/release/done/add/log/decide/board
└── .claude/
    ├── settings.json          # Plugin (ponytail, pinned), model, permissions, hooks
    ├── hooks/clock.sh         # Injects time left into context
    ├── agents/scout.md        # Haiku, read-only research + context7
    ├── agents/judge.md        # Sonnet, pre-submission critique + playwright
    └── commands/              # /kickoff /slice /cut /ship /pitch /sync /claim /handoff
```

Created per clone by `hk.sh init` (gitignored, never committed): `.hackathon/state/` (a git worktree of the `hackathon-state` branch holding `BOARD.md`, `LOG.md`, `DECISIONS.md`), `.hackathon/.me`, `.seen`, `.fetched`.

---

## 2. Setup

### Prerequisites
- Claude Code **2.1.324 or later** (pinning the plugin marketplace to a ref needs it).
- **Node.js on your PATH** (ponytail's hooks, the `npx` MCP servers, and the installer's JSON merge).
- git and bash. Scripts avoid bash 4 features and GNU-only flags for macOS, but were only tested on Linux. A shared git remote (GitHub) for teams.

### Steps
1. **Install into your repo** (it must already be a git repo):
   ```bash
   git clone https://github.com/CriticalRegion/Claudhino-s_harnesses
   bash Claudhino-s_harnesses/hackathon-team-v2/install.sh /path/to/your-repo
   ```
   Nothing of yours is overwritten. `.gitignore` gets missing lines appended; `CLAUDE.md` gets the harness section appended once; `.mcp.json` and `.claude/settings.json` are deep-merged (your scalar values win, lists are unioned). If you already have a harness file that differs (say, your own `commands/ship.md`), it is skipped and reported; `--force` replaces those. Re-running is safe.
2. **Set the deadline** (or let `/kickoff` do it): `echo "2026-11-23T14:00" > .hackathon/deadline` (local time).
3. **Commit and push** the harness so teammates get the same rules.
4. **Each person, once per clone:** `bash .hackathon/bin/hk.sh init <yourname>`. The first person creates the shared `hackathon-state` branch on the remote; everyone else attaches to it. It also enables the pre-push hook (unless you already use `core.hooksPath`, e.g. husky; then it leaves yours alone and says so).
5. **Start Claude Code interactively once** with `claude` and accept the workspace trust dialog. Until you do, Claude Code ignores this project's `permissions.allow` list (you'd get a prompt for every command). Accept the ponytail plugin prompt; if it doesn't appear: `/plugin marketplace add DietrichGebert/ponytail`, `/plugin install ponytail@ponytail`, `/reload-plugins`.
6. **Sign in to remote MCP servers:** `/mcp`, select `github` and `vercel`. `context7` and `playwright` run locally via `npx`; the first Playwright run may download a browser.
7. **Verify:** a session starts with `HACKATHON: ...h...m left.` (once the deadline is set) and, in a team, `OPEN TASKS:`. `/mcp` shows four servers. `/agents` lists scout and judge.

---

## 3. Workflow

| When | Command | What happens |
|---|---|---|
| Hour 0 | `/kickoff <brief, theme, deadline, team size>` | Picks one idea, fills `PLAN.md`, writes the deadline, scaffolds, adds a fast `check` script, deploys hello-world. Team: creates `contracts/` stubs, assigns directory owners, adds board tasks |
| Hours 1 to ~-4h | `/slice` (repeat) | Builds the earliest unfinished demo-path step (or your claimed task) end to end, starts the dev server if needed, verifies in a browser, commits |
| Whenever behind | `/cut` | Compares time left to milestones, cuts or fakes, updates the cut list, releases cut tasks |
| Last hour | `/ship` | Clean deploy, README with honest FAKE list, 2-minute demo script, submission text, runs `judge` |
| Anytime | `/pitch` | Tagline, 60-second pitch, short submission description |

---

## 4. How each piece works

### Ponytail
A plugin that makes the agent behave like a "lazy senior dev": check whether code already exists or is needed at all, then write the minimum that works. It's pinned to tag `v5.3.3` in `settings.json` (`extraKnownMarketplaces.ponytail.source.ref`) so a new release can't change behaviour mid-event; bump the ref deliberately. Say `stop ponytail` for polish-heavy UI work, `/ponytail` to resume, `/ponytail-help` for levels. Its shortcuts are marked `ponytail:`; `/ponytail-debt` lists them.
- Maker's benchmark: ~54% less code, ~20% lower cost. JetBrains' independent test: ~15% less code, ~10% lower cost, 11% faster. Plan on the smaller numbers.

### CLAUDE.md
Loaded every turn, so it's short. Demo path only; vertical slice first; fake what judges can't see and mark it `FAKE:`; boring hosted stack; check docs via context7; deploy early; push to main only when it runs; obey the clock line. Token rules: scout for exploration, no re-reads, tail logs, test only the riskiest function. The team section only applies once `.hackathon/state/` exists.

### Clock hook (`clock.sh`)
At session start (and after `/clear` or `/compact`) it prints the time left. On each prompt it prints only in the last 4 hours:
- > 4h: `HACKATHON: Xh Ym left.`
- 1-4h: finish the vertical slice, then polish; cut anything off the demo path.
- < 1h: **feature freeze**; only demo-path bugs, README, demo video, submission.
- Past: only submit.

Silent while the deadline file holds its placeholder. If the value can't be parsed it says so at session start (not on every prompt). Tolerates Windows line endings; works with GNU and BSD `date`.

### Agents
- **scout** (Haiku): `Read, Grep, Glob, mcp__context7__*`. Answers in <= 10 lines.
- **judge** (Sonnet): `Read, Grep, Glob, mcp__playwright__*`. Walks the live URL from PLAN.md, scores each criterion 1-5 with evidence, lists the top three quick fixes, flags overclaims vs `FAKE:` items. It can't start your app, so deploy or start it first.

### MCP servers (`.mcp.json`)
| Server | Purpose | Notes |
|---|---|---|
| `context7` | Current library docs | Pinned `@upstash/context7-mcp@4.7.3` |
| `playwright` | Headless browser for the demo path | Pinned `@playwright/mcp@0.0.86` |
| `github` | Repo, issues, PRs from chat | Remote; sign in via `/mcp` |
| `vercel` | Deployments and status | Remote; sign in via `/mcp` |

Versions are pinned so `npx` can't pull a changed package during the event. Every server adds tool definitions to context; delete the ones you won't use.

### Permissions (`settings.json`)
- **Allowed without prompting:** git, npm/npx/pnpm, node, python3, ls, grep, curl to localhost, `hk.sh`, context7 and playwright tools. Be clear-eyed: allowing `node`, `python3` and `npx` is effectively allowing any command, so the deny list below is a guard against accidents, not a security boundary.
- **Asks first:** `git reset --hard`, `git clean`, `git checkout -- …`, `git restore`, `git branch -D` (the ways an agent loses an afternoon of work).
- **Denied:** reading `node_modules`, `.next`, `dist`, `build` at any depth; lockfiles; `.env`, `.env.local`, `.env.*.local`, `.env.production` (these also block `cat`/`head` of them in Bash); every form of force-push (`--force`, `-f`, `+refspec`); `rm -rf /…` and `rm -rf ~…`.
- Default model `sonnet`. Switch to `opus` for one hard problem, then back.

### Pre-push hook
Pushes to `main`/`master` run `npm run check` if `package.json` defines it (`/kickoff` adds a fast one: typecheck/lint, not a full build). Other branches push freely. Emergency bypass: `HK_SKIP=1 git push`. `hk.sh` never triggers it, because it never pushes your code.

---

## 5. Team coordination

Agents don't chat. Git is the message bus, and `hk.sh` is the only writer.

**Where the state lives.** `BOARD.md`, `LOG.md` and `DECISIONS.md` live on a separate branch, `hackathon-state`, checked out as a git worktree at `.hackathon/state/`. Consequences:
- Coordination never commits, pushes, pulls or rebases your code, so a half-finished change is never pushed to main by a `log` or `claim`, and a failing pre-push check never blocks the board.
- It works the same from any code branch.
- Agents read the files directly; they change them only through `hk.sh`.

**Board:** `| id | owner | status | ref |`. Claiming edits the row and pushes; the remote is the lock. If two people claim the same task at the same moment, exactly one push wins and the other gets `LOST RACE` (tested with simultaneous claims). Edits to *different* rows never conflict, even adjacent ones: `init` registers a row-wise merge driver for `BOARD.md`. `LOG.md` and `DECISIONS.md` use union merge, so concurrent appends both survive.

**Commands**
| Command | Effect |
|---|---|
| `/sync` | `hk.sh sync` (refresh board, push anything pending, show new lines + open tasks), then `git pull --rebase --autostash` for code |
| `/claim <id>` | `CLAIMED`, `ALREADY YOURS`, `TAKEN by @x`, `LOST RACE`, or `OFFLINE` (claim not made; the lock needs the remote) |
| `/handoff <id> <path:line>` | Smoke test, commit, **push code**, `hk.sh done`, optional `UNBLOCKS`/`ASK`/`decide` lines |
| `hk.sh add <id> <ref>` | Add a task row (used by `/kickoff`) |
| `hk.sh release <id>` | Give a task back |
| `hk.sh log "<EVENT text>"` / `decide "<text>"` | One line to LOG.md / DECISIONS.md |
| `hk.sh board` | Print the board |

**Honest results.** Exit 0 means it reached the remote. Exit 2 with `NOT PUSHED` means it's saved locally (offline) and `hk.sh sync` (or the next session start) will push it. Exit 1 means refused, nothing changed remotely.

**Automatic notifications**
- Session start (and `/clear`, resume): `hk.sh sync --hook` prints new lines and open tasks.
- Every prompt: `hk.sh peek` prints `TEAM UPDATES` only if a teammate changed the board/log/decisions since you last saw it. It reports from the previous background fetch and starts the next one (at most every 20 s), so it never delays your prompt, even with no network. Own lines and finished-task rows are filtered out. No update = zero tokens.
- In a clone that hasn't run `init` (or a solo project), both hooks print nothing.

**Rules baked into CLAUDE.md:** edit only your directory (Owners in PLAN.md); `contracts/` changes need an `ASK` or `decide` line first; shared files need a `CLAIM-FILE` line; OFFLINE / NOT PUSHED is reported to the human; more than one round trip means ask the human; never force-push. One person integrates and runs `/ship` in the last two hours.

**Known limits**
- Needs a shared remote and everyone running `init` once per clone.
- Notifications arrive at the next prompt, not mid-turn, and lag one fetch (~20 s).
- Two people editing the same code file still get a normal git conflict; `/sync` resolves it.
- `git clean -fdx` deletes `.hackathon/state/` (it's ignored). Re-run `init`; anything not yet pushed is lost.
- Log times are `HH:MM` local time, no date.

---

## 6. Customising

| Want to... | Do this |
|---|---|
| Use Netlify, Railway, Render... | Remove `vercel` from `.mcp.json`; adjust step 4 of `/kickoff` and step 1 of `/ship` |
| Cut MCP token overhead | Remove `github` and use `gh`/git |
| Use a remote other than `origin` | `git config hk.remote <name>` |
| Stronger UI polish / charts / deck | `frontend-design`, `dataviz`, `pptx` skills |
| Different tone or rules | Edit `CLAUDE.md`. Keep it short; every line is paid for on every turn |
| Upgrade ponytail or MCP servers | Bump the `ref` in settings.json / versions in `.mcp.json`, test once before the event |

---

## 7. Troubleshooting

| Symptom | Fix |
|---|---|
| Permission prompt for every command | Workspace not trusted yet: run `claude` interactively in the repo and accept the trust dialog |
| Ponytail does nothing, no errors | Node isn't on the PATH Claude Code sees. Fix PATH, restart `claude` |
| Plugin not enabled | Run the `/plugin` commands in setup step 5 |
| `/mcp` shows github or vercel disconnected | Sign in again from `/mcp` |
| Playwright fails on first run | Browser download pending; retry or `npx playwright install chromium` |
| `hk: not set up in this clone` | `bash .hackathon/bin/hk.sh init <name>` |
| `hk: set git user.name and user.email first` | `git config --global user.name ...` and `user.email ...` |
| `OFFLINE` on claim | Network or auth to the remote failed; the claim was not made. Retry |
| `NOT PUSHED` | Saved locally; `hk.sh sync` retries |
| `STATE CONFLICT` | Your unpushed board edit and a teammate's touched the same row. `cd .hackathon/state && git rebase origin/hackathon-state`, fix `BOARD.md`, `git rebase --continue`, `hk.sh sync` |
| `hk: busy` | Another hk.sh is running; if none is, delete `.hackathon/.lock` |
| Push to main blocked by pre-push | `npm run check` failed; fix it, or `HK_SKIP=1 git push` in an emergency |
| Clock line missing | Deadline file still has the placeholder, or a session-start line says it can't be read |
| Context filling up | `/compact` at a milestone; `/clear` between unrelated tasks |

---

## 8. What was tested

- `tests/run.sh`: 82 checks against throwaway repos and a local bare remote: non-destructive install and idempotent re-install; init/attach; claim/release/done/add/log; TAKEN vs LOST RACE under truly simultaneous claims (5 rounds, one winner each); concurrent log appends (all kept); adjacent-row edits made offline by two people merging cleanly; WIP commits never reaching the remote; board working while the pre-push check fails; offline claim refused and offline done/log queued then pushed by sync; feature branches without upstream; relative remote URLs; running from subdirectories; `peek` returning instantly with an unreachable remote; clock phases, CRLF, bad values; pre-push on main vs feature branches and the bypass.
- A live headless Claude Code 2.1.325 session on a sandbox project: both SessionStart hooks injected the clock line and the board, the pinned MCP servers started and exposed their tools, and the `scout` subagent received exactly `Read, Grep, Glob` plus the context7 tools.
- shellcheck clean (warning level).
- Not tested: macOS (scripts avoid GNU-only flags and fall back to BSD `date` and `perl` for timeouts), Windows, the github/vercel MCP sign-in, and a full `/kickoff` -> `/ship` run on a real project.

---

## 9. Changes from v1

Bugs fixed (each reproduced against v1 first):
- `hk.sh log/claim/done` pushed whatever code you had committed, including unfinished work, to main. Coordination now lives on its own branch.
- A failing pre-push check silently left claims local (teammates could take the same task) while `log` printed `logged` though nothing was pushed. Now: exit codes and `NOT PUSHED` messages are honest.
- `done`/`claim` ignored a failed pull and edited the board in the middle of a conflicted rebase, still printing `DONE`.
- Any pull failure (offline, branch without upstream) was reported as `SYNC CONFLICT`; offline claims were reported as `LOST RACE`.
- Claims of adjacent board rows conflicted; now only same-row edits do.
- The SessionStart hook ran `git pull --rebase --autostash` on your code at every startup, `/clear` and `/compact`. Hooks no longer touch code.
- `peek` could block a prompt for up to 8 s (indefinitely on macOS without `timeout`, or on a credential prompt). It's now non-blocking.
- Subagent `tools: mcp__context7` / `mcp__playwright` isn't a documented form; now `mcp__context7__*` / `mcp__playwright__*` (verified live).
- `Bash(curl:localhost*)` never matched anything (`:*` only works at the end of a rule).
- Read-deny missed `.env.local` (the file Next.js uses) and nested `node_modules`; force-push deny missed `-f` and `+refspec`.
- Install via `cp -r` overwrote your README.md and .gitignore. Now `install.sh` merges.
- Hook commands used relative paths; now `$CLAUDE_PROJECT_DIR`, and scripts locate the project from their own path.
- Feature freeze was "last 20%" in CLAUDE.md but "last 60 minutes" in the clock; now the clock line is the single rule.
- `PLAN.md` had no Owners, Dev command or Live URL fields though commands relied on them; `/kickoff` now creates contracts, owners and board tasks, and adds the `check` script the pre-push hook expects; `/slice` starts the dev server; `/handoff` pushes code before announcing `DONE`.
- Third-party code (ponytail, MCP packages) was unpinned; now pinned.
