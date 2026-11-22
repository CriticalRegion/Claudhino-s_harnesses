# Hackathon Team Harness (v3): full guide

A Claude Code project configuration for hackathons. It spends fewer tokens, steers the agent toward a working, demoable product before the deadline, and lets 2-4 people (each with their own agent) split work without stepping on each other. v3 adds event notifications: the events that matter to your agent reach it mid-task or wake it when idle, without agents chatting.

---

## 1. What it is

```
hackathon-team-v3/
├── install.sh                 # Non-destructive installer (not copied into your repo)
├── tests/run.sh               # End-to-end tests (not copied)
├── README.md, GUIDE.md        # Docs (not copied)
├── CLAUDE.md                  # Always-loaded rules: demo-first, fake-it policy, terse output, team protocol
├── .mcp.json                  # MCP servers: context7, playwright (pinned), github, vercel
├── .gitignore                 # Lines merged into yours: per-clone harness state, .env files, build output
├── .githooks/pre-push         # Pushes to main/master must pass `npm run check` (if defined) and a Python syntax check; announces contracts/ changes
├── .githooks/post-commit      # Marks you active on the board (stale-claim detection), in the background
├── .hackathon/
│   ├── PLAN.md                # Pitch, owners, demo path, URLs, milestones, cut list (filled by /kickoff)
│   ├── deadline               # Local time YYYY-MM-DDTHH:MM; drives the clock hook
│   └── bin/hk.sh              # Team coordination + event hooks (see section 5)
└── .claude/
    ├── settings.json          # Plugin (ponytail, pinned), model, permissions, hooks
    ├── hooks/clock.sh         # Injects time left into context
    ├── agents/scout.md        # Haiku, read-only research + context7
    ├── agents/judge.md        # Sonnet, pre-submission critique + playwright
    └── commands/              # /kickoff /slice /cut /ship /pitch /demo-check /sync /claim /handoff
```

Created per clone by `hk.sh init` (gitignored, never committed): `.hackathon/state/` (a git worktree of the `hackathon-state` branch holding `BOARD.md`, `LOG.md`, `DECISIONS.md`, `SEEN.md`), plus small local files in `.hackathon/` (`.me`, delivery cursors `.seen`/`.ucur`, `.fetched`, `.beat`, `.wakes`, `.warned`, `.watch.pid`, and `.discord` if you set a webhook).

---

## 2. Setup

### Prerequisites
- Claude Code **2.1.324 or later** (pinning the plugin marketplace to a ref needs it).
- **Node.js on your PATH** (ponytail's hooks, the `npx` MCP servers, and the installer's JSON merge).
- git and bash. Scripts avoid bash 4 features and GNU-only flags for macOS, tested on Linux and macOS (`tests/run.sh`). A shared git remote (GitHub) for teams.

### Steps
1. **Install into your repo** (it must already be a git repo):
   ```bash
   git clone https://github.com/CriticalRegion/Claudhino-s_harnesses
   bash Claudhino-s_harnesses/hackathon-team-v3/install.sh /path/to/your-repo
   ```
   Nothing of yours is overwritten. `.gitignore` gets missing lines appended; `CLAUDE.md` gets the harness section appended once; `.mcp.json` and `.claude/settings.json` are deep-merged (your scalar values win, lists are unioned). If you already have a harness file that differs (say, your own `commands/ship.md`), it is skipped and reported; `--force` replaces those. Re-running is safe.
2. **Set the deadline** (or let `/kickoff` do it): `echo "2026-11-23T14:00" > .hackathon/deadline` (local time).
3. **Commit and push** the harness so teammates get the same rules.
4. **Each person, once per clone:** `bash .hackathon/bin/hk.sh init <yourname>`. The first person creates the shared `hackathon-state` branch on the remote; everyone else attaches to it. It also enables the git hooks (pre-push check, contract alerts, activity beats) unless you already use `core.hooksPath`, e.g. husky; then it leaves yours alone and says so. Upgrading from v2 mid-event is fine: the first `sync` adds the `deps` column and `SEEN.md` to your existing board.
5. **Start Claude Code interactively once** with `claude` and accept the workspace trust dialog. Until you do, Claude Code ignores this project's `permissions.allow` list (you'd get a prompt for every command). Accept the ponytail plugin prompt; if it doesn't appear: `/plugin marketplace add DietrichGebert/ponytail`, `/plugin install ponytail@ponytail`, `/reload-plugins`.
6. **Optional, Discord:** in your channel, Settings → Integrations → Webhooks → New Webhook → Copy URL, then `bash .hackathon/bin/hk.sh discord <url>` and `hk.sh discord test`. Each person who wants their events posted does this once; the URL stays in a gitignored local file.
7. **Sign in to remote MCP servers:** `/mcp`, select `github` and `vercel`. `context7` and `playwright` run locally via `npx`; the first Playwright run may download a browser.
8. **Verify:** a session starts with `HACKATHON: ...h...m left.` (once the deadline is set) and, in a team, `TEAM: you are @<name>` and `OPEN TASKS:`. `/mcp` shows four servers. `/agents` lists scout and judge.

---

## 3. Workflow

| When | Command | What happens |
|---|---|---|
| Hour 0 | `/kickoff <brief, theme, deadline, team size>` | Generates 5 ideas, drops ones that already exist, scores originality / real problem / sponsor tech / effort, picks one, fills `PLAN.md`, writes the deadline, scaffolds, adds a fast `check` script, deploys hello-world. Team: creates `contracts/` stubs, assigns directory owners, adds board tasks |
| Hours 1 to ~-4h | `/slice` (repeat) | Builds the earliest unfinished demo-path step (or your claimed task) end to end, starts the dev server if needed, verifies in a browser, commits |
| Whenever behind | `/cut` | Compares time left to milestones, cuts or fakes, updates the cut list, releases cut tasks |
| Last hour | `/ship` | Clean deploy, README with honest FAKE list, 2-minute demo script, submission text, runs `judge` |
| After each deploy | `/demo-check` | Walks the demo path in a real browser and logs `DEMO GREEN` or `DEMO RED: step n ...` for the team |
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
Pushes to `main`/`master` run `npm run check` if `package.json` defines it (`/kickoff` adds a fast one: typecheck/lint, not a full build), then, if the repo has tracked `.py` files, a syntax check of each (compiled in memory; no `__pycache__` written). Other branches push freely. Emergency bypass: `HK_SKIP=1 git push`. After the checks, if the push changes files under `contracts/`, it starts `hk.sh contract` in the background, which waits until the push has landed and logs `CONTRACT-CHANGED` (this happens with the bypass too). `hk.sh` never triggers the checks, because it never pushes your code.

---

## 5. Team coordination and events

Agents don't chat. Git is the message bus, `hk.sh` is the only writer, and messages are **events** (DONE, BLOCKED, ASK, ANSWER, ...), not dialogue.

**Where the state lives.** `BOARD.md`, `LOG.md`, `DECISIONS.md` and `SEEN.md` live on a separate branch, `hackathon-state`, checked out as a git worktree at `.hackathon/state/`. Coordination never commits, pushes, pulls or rebases your code, works from any code branch, and agents change those files only through `hk.sh`.

**Board:** `| id | owner | status | deps | ref |`. `deps` lists the tasks this one waits on (`hk.sh add t3-web web/ --after t1-api`). Claiming edits the row and pushes; the remote is the lock, so of two simultaneous claims exactly one wins and the other gets `LOST RACE`. Edits to different rows never conflict (a row-wise merge driver handles `BOARD.md` and `SEEN.md`); `LOG.md` and `DECISIONS.md` use union merge.

### Commands
| Command | Effect |
|---|---|
| `/sync` | `hk.sh sync` (refresh, push anything pending, show `URGENT FOR YOU` + new lines + open tasks with `STALE` flags), then `git pull --rebase --autostash` for code |
| `/claim <id> [--take]` | `CLAIMED`, `ALREADY YOURS`, `TAKEN by @x`, `TAKEN ... but STALE`, `LOST RACE`, `OFFLINE`; `--take` takes over a stale task (`TOOK-OVER`) |
| `/handoff <id> <path:line>` | Smoke test, commit, push code, `hk.sh done` (dependents are notified), optional `UNBLOCKS`/`ASK`/`decide`, `/demo-check` after a deploy |
| `/demo-check [url]` | Playwright walk of the demo path, then `hk.sh demo green|red "..."` |
| `hk.sh add <id> [ref] [--after a,b]` | Add a task (used by `/kickoff`) |
| `hk.sh release <id>` | Give a task back |
| `hk.sh log "<EVENT text>"` | `BLOCKED ...`, `ASK @x: ...`, `ANSWER @x: ...`, `UNBLOCKS @x: ...`, `CLAIM-FILE <path>` |
| `hk.sh note "@name text"` | A human's note to someone's agent (urgent for them) |
| `hk.sh decide "<text>"` / `board` | One line to DECISIONS.md / print the board |
| `hk.sh discord <url>\|off\|test` | Post your own events to a Discord channel |

Exit codes: 0 reached the remote; 2 `NOT PUSHED` (saved locally, `sync` retries); 1 refused, nothing changed remotely.

### How an event reaches an agent
Every new line a teammate adds is classified for **you** (your handle is in `.hackathon/.me`; the session start says `TEAM: you are @name`):

| Urgent for you | FYI |
|---|---|
| `ASK @you`, `ANSWER @you`, `NOTE @you`, `UNBLOCKS @you`, any line naming `@you` (e.g. `TOOK-OVER t3 from @you`) | everything else: claims, other people's DONE/BLOCKED/ASK, decisions, new tasks |
| `DONE <id>` where one of your open tasks depends on `<id>` | |
| `CONTRACT-CHANGED <files>` touching the ref of your task or of a task it depends on | |
| `CLAIM-FILE <path>` on a file you've changed but not pushed, or in your owned directory | |
| `DEMO RED` in the last 4 hours | `DEMO GREEN`, `DEMO RED` earlier |

Three delivery paths, each costing only the event line (~20-40 tokens):
1. **Mid-task (`PostToolUse` hook):** after every tool call `hk.sh posttool` checks, locally and in milliseconds, whether the last background fetch brought urgent lines; if so they're added next to the tool result as `TEAM URGENT for you (@name) ...`. Calls inside subagents (scout/judge) are skipped so the main agent gets them.
2. **Idle (`Stop` and `SessionStart` hooks with `asyncRewake`):** when a turn ends, `hk.sh watch` keeps fetching (every 15 s; every 5 s in the last 4 hours) and exits 2 when an urgent line arrives, which wakes the agent with it. One watcher per clone; a new one replaces the old; it gives up after ~1 hour idle. At most 6 wakes per hour (`HK_WAKE_CAP`); over the cap, the event waits for your next prompt.
3. **Next prompt (`UserPromptSubmit` hook):** `hk.sh peek` shows anything urgent not yet delivered plus the FYI lines as `TEAM UPDATES`. It never waits on the network.

A line is delivered once, whichever path gets it first. Nothing is printed when nothing changed. In a clone without `init` every hook is silent.

### Guards
- **Loop guard:** an agent may answer an ASK once (`ANSWER @x: ...`). If the same person asks it again within 30 minutes, that ASK isn't delivered as urgent: the receiving clone logs `ESCALATE @asker -> @you (2nd ASK, humans decide): ...`, which wakes no one and is shown to both sides (and on Discord) for the humans to settle.
- **Collision guard (`PreToolUse` on Edit/Write/NotebookEdit):** before your agent edits a file a teammate `CLAIM-FILE`d in the last 3 hours, or one in a teammate's directory per the `Owners` line in PLAN.md (`web/ -> @bob, api/ -> @alice`), the first attempt is refused with `COLLISION WARNING: ...`. The agent sees it before anything is written; if the human says go ahead, a retry goes through (one warning per file). `HK_COLLISION=warn` instead lets the edit happen and adds the warning afterwards (Claude Code shows `PreToolUse` context next to the tool result, so the agent then reverts; we measured that and made refusal the default).
- **Stale claims:** every code commit (post-commit hook, at most every 10 min) and every `hk.sh` action records you as active in `SEEN.md`. A `doing` task whose owner has been inactive for 45 min (`HK_STALE_MIN`) shows `STALE` in `sync`; `claim <id> --take` then takes it over and the old owner is told.
- **Contract alerts:** a push to main that touches `contracts/` is announced once it lands, and is urgent for the owners of dependent tasks.

### Discord (events out)
`hk.sh discord <url>` (only `https://discord.com/api/webhooks/...` URLs accepted) makes your clone post each of **your own** events after it reaches the remote, one line with an emoji per type (✅ DONE, ⛔ BLOCKED, ❓ ASK, 💬 ANSWER, 🚨 ESCALATE, 🔴/🟢 DEMO, 📜 CONTRACT-CHANGED, 🙋 CLAIMED, 📝 NOTE). Each event starts in exactly one clone, so nothing is posted twice; if only some teammates set the webhook, only their events appear. Mentions are disabled (`allowed_mentions: []`), so a line can't ping `@everyone`. The URL lives in `.hackathon/.discord` (gitignored, mode 600); anyone with it can post to your channel, so don't commit or share it. Humans reach agents with `hk.sh note`, not through Discord.

### Permission modes matter for answers
In the default (manual) permission mode, the project allow rule `Bash(bash .hackathon/bin/hk.sh *)` lets a woken agent post its `ANSWER` line without a prompt (verified live). In **auto mode**, Claude Code's safety classifier treated the same call as an unsanctioned reply to another agent and blocked it; the agent then told its human the answer and the exact line to post, as CLAUDE.md instructs. That keeps a human in the loop for agent-to-agent replies, which is the point; we don't try to get around it.

### Autonomous mode (`hk.sh auto`)
For stretches where nobody wants to babysit: agents decide for themselves and keep working.

| Command | Effect |
|---|---|
| `hk.sh auto on [90m\|2h]` | Team-wide (default 3 h budget). Logged as `AUTO ON`, which wakes every idle agent |
| `hk.sh auto off` | Team-wide kill switch, reaches every agent within ~15 s |
| `hk.sh auto on --me` / `off --me` / `clear --me` | Override for your clone only / back to the team setting |
| `hk.sh auto status` | Team setting, your override, and what your agent is doing |

While it's on for your agent:
- **No permission pauses:** a `PermissionRequest` hook approves every prompt. Deny rules are checked before any prompt, so the deny list (force-push, `rm -rf /`, `.env` reads, large build dirs) still blocks in every mode.
- **No questions:** `AskUserQuestion` is refused with "pick the option you judge best and log it with `hk.sh decide`".
- **No stopping while work remains:** when the agent ends a turn, the `Stop` hook names the next concrete step: finish your task → claim the next unblocked one → fix `DEMO RED` → `/demo-check` (only if PLAN.md has a URL). When nothing is left, it lets the agent stop.
- **Escalations become decisions:** an `ESCALATE` addressed to an autonomous asker is urgent for it, and it decides.
- **It always ends:** autonomous off (team or `--me`), the time budget, the deadline, or 3 consecutive turn-ends with no change to the board, log, commits or working tree. The last one logs `STUCK (autonomous): ...` for the humans instead of spinning.
- It's designed for the default (manual) or accept-edits permission modes. In Claude Code's auto mode, the safety classifier still reviews actions and may block some (we saw it block agent-to-agent replies).

**Risk:** an autonomous agent acts on teammates' board messages and approves its own commands with nobody watching. A wrong or malicious board line gets acted on. Keep the deny list, keep budgets short, and use a container or dev container for long unattended runs. It is off unless someone runs `hk.sh auto on`.

### Solo mode (`hk.sh solo`)
For the end of the event, when one agent should do the remaining small fixes alone.

| Command | Effect |
|---|---|
| `hk.sh solo @alice [2h]` | Alice's agent becomes autonomous (default 3 h) and owns the repo; everyone else is muted. Logged as `SOLO @alice` |
| `hk.sh solo off` | Back to normal; wakes everyone with `SOLO OFF` |

- **The solo agent** may edit any file (no collision warnings, no folder ownership), change contracts, and take any task, even someone else's (`TOOK-OVER ... (solo)`). Only human notes (`hk.sh note "@alice ..."`) and mode changes wake it; teammates' events become FYI.
- **Everyone else** gets one `SOLO` notice, then their team notifications are muted (nothing mid-task, nothing at the next prompt) until `solo off`. They aren't blocked: if their human asks them to do something, they can, so coordinate with the solo agent's human.
- Solo overrides the team auto setting: only the solo agent is autonomous. Its human can still opt out with `hk.sh auto off --me`.

**Verified live** (interactive Claude Code, manual permission mode): `AUTO ON` from a teammate woke an idle agent, which claimed and finished two dependent tasks with its file-write prompts auto-approved ("Allowed by PermissionRequest hook"); told to stop after one task, the `Stop` hook sent it on to the next; with no demo URL it logged `STUCK` and stopped; `SOLO @alice` made it finish two tasks in a teammate's folder without collision warnings; `AUTO OFF` / `SOLO OFF` woke it and it stopped without taking a new task.

**Rules baked into CLAUDE.md:** events aren't conversation; DONE/CONTRACT-CHANGED → pull and adapt; ASK → one ANSWER; NOTE → follow; COLLISION → ask first; DEMO RED → fix only your step; ESCALATED → tell the human; woken with nothing relevant → one line and stop; blocked hk.sh call → tell the human the line.

**Known limits**
- Needs a shared remote and everyone running `init` once per clone.
- Events lag one fetch: ~15-20 s normally, ~5 s in the last 4 hours. An idle agent stops being woken after ~1 hour without a turn (the watcher's limit); the next prompt still gets everything.
- Headless runs (`claude -p`) kill background hooks at exit, so they get mid-task and next-prompt delivery but no wake-ups.
- Two people editing the same code file still get a normal git conflict; `/sync` resolves it.
- `git clean -fdx` deletes `.hackathon/state/` (it's ignored). Re-run `init`; anything not yet pushed is lost.
- Log times are `HH:MM` local time, no date; the 30-minute loop-guard and 3-hour CLAIM-FILE windows use them.

---

## 6. Customising

| Want to... | Do this |
|---|---|
| Use Netlify, Railway, Render... | Remove `vercel` from `.mcp.json`; adjust step 4 of `/kickoff` and step 1 of `/ship` |
| Cut MCP token overhead | Remove `github` and use `gh`/git |
| Use a remote other than `origin` | `git config hk.remote <name>` |
| Tune notifications | `HK_WAKE_CAP` (wakes/hour, default 6), `HK_STALE_MIN` (default 45), `HK_COLLISION=warn`, `HK_FETCH_EVERY` (seconds between background fetches, default 20), `HK_WATCH_INTERVAL` (watcher poll, default 15 / 5 late), set in the environment you start `claude` from |
| Turn wake-ups off | Remove the `watch` entries from the `Stop` and `SessionStart` hooks in `.claude/settings.json` |
| Tune autonomous mode | `HK_AUTO_STUCK` (no-progress turn-ends before stopping, default 3); `HK_STOP_STYLE=block` for the classic Stop-hook form; budgets via `hk.sh auto on 90m` / `solo @x 2h` |
| Remove autonomous/solo entirely | Delete the `PermissionRequest` hook and the `autostop` entry under `Stop` in `.claude/settings.json` |
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
| Push to main blocked by pre-push | `npm run check` or the Python syntax check failed (the file and line are printed); fix it, or `HK_SKIP=1 git push` in an emergency |
| Clock line missing | Deadline file still has the placeholder, or a session-start line says it can't be read |
| Context filling up | `/compact` at a milestone; `/clear` between unrelated tasks |
| Agent never woken | It only wakes for urgent events (table in section 5) and after a turn has ended; check `.hackathon/.watch.pid` is a live process and `.hackathon/.wakes` isn't at the hourly cap |
| Agent ignores lines for its handle | Start a new session (`/clear`) so it sees `TEAM: you are @name` |
| Woken agent's `ANSWER` blocked | Auto mode's classifier asks for a human on agent-to-agent replies; approve it, post the line yourself, or use the default permission mode |
| `COLLISION WARNING` on a file you meant to edit | Tell the agent it's fine; the retry goes through |
| Discord shows nothing | `hk.sh discord test`; only the events of people who set the webhook are posted |
| Autonomous agent keeps getting prompts | It's in Claude Code's auto mode (classifier) or `hk.sh auto status` says off; use manual/accept-edits mode and check the status line |
| Autonomous agent stopped early | Work ran out (nothing claimable, demo GREEN or no URL), the budget ended, or it logged `STUCK`; `hk.sh auto status` says which |
| Muted and want news anyway | Someone is solo; `hk.sh board` and `hk.sh sync` still work, or ask for `hk.sh solo off` |

---

## 8. What was tested

- `tests/run.sh`: 195 checks against throwaway repos and a local bare remote. Everything from v2 (install/merge, claims and races, offline handling, row merges, WIP isolation, pre-push, Python check, clock) plus, for v3: dependency routing (DONE is urgent only for the dependent task's owner); `posttool` JSON validity, speed and subagent skip; ASK/NOTE/ANSWER mentions; the loop guard logging ESCALATE and never waking; the watcher waking (exit 2) on an urgent event, staying quiet otherwise, replacing an older watcher, and respecting the wake cap with the event still delivered at the next prompt; the collision guard (CLAIM-FILE, owned directory, own directory, refuse-once then retry, `HK_COLLISION=warn`); contract alerts on push to main; post-commit activity beats, STALE display and `--take`; Discord posts to a local fake webhook (valid JSON, mentions disabled, only your own events, non-Discord URLs refused); upgrading a v2 board in place; `clock.sh --minutes`; autonomous mode (permit JSON, AskUserQuestion refusal, Stop-hook next steps through a whole board, work-ran-out stop, DEMO RED, no-URL stop, STUCK after 3, per-person override, time budget, AUTO ON/OFF reaching everyone, ESCALATE to an autonomous asker); solo mode (solo agent autonomous and unrestricted, others muted but still able to work, human notes still delivered, takeover of any task, SOLO OFF); claims no longer hiding teammates' news.
- A live interactive Claude Code 2.1.325 session (Haiku) in tmux on a sandbox with two teammates: a teammate's NOTE arrived mid-task via `PostToolUse`; an idle agent was woken by a dependency's DONE and replied in one line; the collision guard refused an edit in a teammate's directory before writing; a woken agent answered an ASK with one `ANSWER` line in manual mode, was blocked by the classifier in auto mode (and told its human instead); a follow-up ASK became `ESCALATE` without waking anyone. Two bugs found this way were fixed (agents didn't know their own handle; `PreToolUse` warnings arrived after the edit).
- shellcheck clean (warning level). Linux only for v3; the v2 parts also passed on macOS.
- Not tested: macOS and Windows for the v3 hooks, a real Discord server (a local fake webhook was used), the github/vercel MCP sign-in, and a full `/kickoff` -> `/ship` run on a real project.

---

## 9. Changes from v2

- Autonomous mode (`hk.sh auto`) and solo mode (`hk.sh solo`): self-approved prompts, no questions, Stop-hook continuation until work runs out, budgets, STUCK detection, kill switch, muting.
- Event routing: urgent vs FYI per person, using a new board `deps` column (`add --after`).
- Mid-task delivery (`PostToolUse`), idle wake-ups (`asyncRewake` watcher on `Stop`/`SessionStart`), and urgent-first next-prompt delivery; each event delivered once.
- Loop guard (one ASK/ANSWER round trip, then ESCALATE for humans) and a wake cap.
- Collision guard (`PreToolUse`), contract-change alerts (pre-push), stale-claim detection with `--take` (post-commit beats, `SEEN.md`), `/demo-check` with `DEMO GREEN/RED`.
- `hk.sh note`, `demo`, `discord`; Discord webhook posting.
- `clock.sh --minutes`; `hk.sh` clears git's hook environment so it's safe to call from git hooks.
- The v1 → v2 changes are listed in `hackathon-team-v2/GUIDE.md`.
