# Hackathon Team Harness (v1): full guide

> **Deprecated.** Use [hackathon-team-v3](../hackathon-team-v3/) instead. v1 has known bugs: board commands push unfinished code to main, report success when offline, and the `cp -r` install overwrites your README and `.gitignore` (details in the [v2 guide](../hackathon-team-v2/GUIDE.md#9-changes-from-v1)). Kept only for reference; it gets no fixes.

A Claude Code project configuration for hackathons. It does two things: it spends fewer tokens, and it steers the agent toward a working, demoable product before the deadline.

---

## 1. What it is

A folder of config files you drop into your repo root. Claude Code reads them automatically.

```
hackathon-team-v1/
├── CLAUDE.md                  # Always-loaded rules: demo-first, fake-it policy, terse output
├── README.md                  # Short install notes
├── GUIDE.md                   # This file
├── .mcp.json                  # MCP servers: context7, playwright, github, vercel
├── .gitattributes             # Union-merge for LOG.md and DECISIONS.md (concurrent appends never conflict)
├── .githooks/pre-push         # Runs `npm run check` if defined, so main stays demoable
├── .hackathon/
│   ├── PLAN.md                # Pitch, demo path, milestones, cut list (filled by /kickoff)
│   ├── deadline               # ISO timestamp; drives the clock hook
│   ├── BOARD.md               # Task table: id | owner | status | ref  (claiming = lock)
│   ├── LOG.md                 # Append-only, one telegraphic line per event
│   ├── DECISIONS.md           # One-line settled decisions
│   └── bin/hk.sh              # The only coordination script: init/sync/peek/claim/done/log
└── .claude/
    ├── settings.json          # Plugin (ponytail), model, permissions, hooks
    ├── hooks/clock.sh         # Injects time-left into context
    ├── agents/
    │   ├── scout.md           # Haiku, read-only research
    │   └── judge.md           # Pre-submission critique against judging criteria
    └── commands/
        ├── kickoff.md         # /kickoff  brief -> plan -> deployed skeleton
        ├── slice.md           # /slice    build next thin end-to-end slice
        ├── cut.md             # /cut      scope check when behind
        ├── ship.md            # /ship     final-hour checklist
        ├── sync.md            # /sync     pull teammates' work, show only what changed
        ├── claim.md           # /claim    take a board task (lock)
        ├── handoff.md         # /handoff  finish a task and tell the team in one line
        └── pitch.md           # /pitch    tagline, pitch, submission text
```

---

## 2. Setup

### Prerequisites
- Claude Code **2.1.290 or later** (terminal or desktop app). Ponytail's live metrics need this version.
- **Node.js on your PATH.** Ponytail's hooks and the `npx`-based MCP servers need it. Without it, ponytail's hooks silently do nothing.
- A git repo for your project, and accounts for GitHub and Vercel (or swap in your own host).

### Steps

1. **Copy the harness into your repo root**
   ```bash
   git clone https://github.com/CriticalRegion/Claudhino-s_harnesses
   cp -r Claudhino-s_harnesses/hackathon-team-v1/. /path/to/your-repo/
   cd /path/to/your-repo
   rm GUIDE.md   # optional: keep it if you want the docs in your repo
   ```
   Don't overwrite an existing `CLAUDE.md` or `.mcp.json`. Merge them by hand.

2. **Set your deadline** (ISO format, local time)
   ```bash
   echo "2026-11-23T14:00" > .hackathon/deadline
   ```
   The file ships with a placeholder, and the clock hook stays silent until you set a real time.

3. **Start Claude Code and accept the project plugin prompt**
   ```bash
   claude
   ```
   `settings.json` registers the ponytail marketplace and enables the plugin. If ponytail doesn't activate, install it manually:
   ```
   /plugin marketplace add DietrichGebert/ponytail
   /plugin install ponytail@ponytail
   /reload-plugins
   ```

4. **Authenticate the remote MCP servers**
   ```
   /mcp
   ```
   Select `github` and `vercel` and complete sign-in. `context7` and `playwright` run locally via `npx` and need no sign-in. The first Playwright run may download a browser.

5. **Team setup (each person, once)**: commit and push the harness, have everyone clone, then each person runs
   ```bash
   bash .hackathon/bin/hk.sh init <yourname>
   ```
   This saves your handle (gitignored) and enables the pre-push hook. Edit `.hackathon/BOARD.md` so the tasks match your plan, and push.

6. **Verify**
   - `/plugin` shows `ponytail` enabled.
   - `/mcp` shows all four servers connected.
   - The session start prints a line like `HACKATHON: 23h59m left.`
   - `/help` lists `/kickoff`, `/slice`, `/cut`, `/ship`, `/pitch`.

---

## 3. Workflow

| When | Command | What happens |
|---|---|---|
| Hour 0 | `/kickoff <brief, theme, deadline, team size>` | Picks one idea with the best demo-to-effort ratio, fills `PLAN.md` (pitch, 3-5 step demo path, stack, milestones, cut list), scaffolds, commits, deploys hello-world, reports the live URL |
| Hours 1 to ~70% | `/slice` (repeat) | Builds the earliest unfinished demo-path step as a thin end-to-end slice, verifies in a real browser, commits |
| Whenever behind | `/cut` | Compares time left to unfinished milestones, proposes what to cut or fake, updates the cut list |
| Last hour | `/ship` | Clean deploy, README, 2-minute timed demo script, submission text, runs the `judge` agent, applies only fixes under 10 minutes |
| Anytime | `/pitch` | Tagline, 60-second pitch, short submission description |

The `judge` and `scout` agents are invoked automatically by Claude when relevant, or by name ("use the judge agent").

---

## 4. How each piece works

### Ponytail (token and code efficiency)
A plugin that makes the agent behave like a "lazy senior dev": check whether the code already exists, can be one line, or needs no code at all, and only then write the minimum that works. Less code means fewer output tokens, less to review, and fewer bugs.

- The maker advertises about 54% less code, 22% fewer tokens, 20% lower cost. That's their own benchmark.
- JetBrains' independent paired test measured about 15% less code, 10% lower cost and 11% faster. Plan on the smaller numbers.
- It can feel aggressive on unfamiliar code or polish-heavy UI work. Say `stop ponytail` to turn it off, `/ponytail` to resume, `/ponytail-help` for levels and commands.
- Its shortcuts are marked in code with `ponytail:` comments. `/ponytail-debt` collects them, which is useful after the hackathon.

### CLAUDE.md (always-loaded rules)
Kept short on purpose, since it's loaded every turn. Key rules:
- Build only the demo path; everything else goes on the cut list.
- Vertical slice first, then widen.
- **Fake what judges can't tell**, and tag it `// FAKE:` so your pitch and README stay honest.
- Boring, hosted, zero-config stack. No auth or new infra unless it *is* the idea.
- Check docs via context7 instead of guessing APIs.
- Deploy in the first hour, commit at every working state.
- Feature freeze for the last 20% of time.
- Token rules: use `scout` for exploration, don't re-read files, don't paste long logs, no narration, test only the riskiest function, `/compact` at milestones.

### Clock hook (`clock.sh`)
Runs at session start and, when under 4 hours remain, on every prompt. It prints a single line to the agent's context:
- More than 4h: `HACKATHON: Xh Ym left.`
- Under 4h: finish the vertical slice, then polish; cut anything off the demo path.
- Under 1h: **feature freeze.** Only demo-path bugs, README, demo video, submission.
- Past the deadline: only submit.

It costs about 20 tokens and makes the agent scope to the clock without being asked.

### Agents
- **`scout`** (Haiku, read-only tools plus context7): repo exploration and doc lookups, answers in 10 lines or fewer. Keeps large file reads out of the main context and runs on a cheaper model.
- **`judge`** (Sonnet, read-only plus Playwright): reads `PLAN.md` and the README, walks the live demo, scores each judging criterion 1-5 with evidence, lists the top three quick fixes, and flags anything broken or overclaimed.

### MCP servers (`.mcp.json`)
| Server | Purpose | Notes |
|---|---|---|
| `context7` | Current library docs on demand | Fewer hallucinated-API debug loops |
| `playwright` | Drives a headless browser to test the demo path | Catches broken demos early |
| `github` | Repo, issues, PRs from chat | Remote; needs sign-in |
| `vercel` | Deployments and project status | Remote; needs sign-in |

Every MCP server adds its tool definitions to your context. Delete the ones you won't use.

### Permissions (`settings.json`)
- **Allowed without prompting:** git, npm/npx/pnpm, node, python3, ls, grep, curl to localhost, context7 and playwright tools. This avoids permission interruptions during a time crunch.
- **Denied:** reading `node_modules`, `.next`, `dist`, `build`, lockfiles and `.env`; force-push; `rm -rf /*`. This prevents huge accidental reads that burn tokens and secret leakage.
- Default model is `sonnet`. Switch to `opus` for one hard problem, then back.

---

## 5. Team coordination (several people, several agents)

Agents don't chat. Git is the message bus, and `hk.sh` is the only interface.

**State files** (all in `.hackathon/`)
- `BOARD.md`: `| id | owner | status | ref |`. Claiming a task edits its row and pushes, so two simultaneous claims can't both succeed.
- `LOG.md`: `HH:MM @name EVENT text`, append-only. Events: `DONE`, `BLOCKED`, `ASK @x`, `CLAIM-FILE <path>`, `UNBLOCKS @x`. Pointers (`path:line`), never code or logs.
- `DECISIONS.md`: one line per settled choice so agents don't re-argue.

**Commands**
| Command | Effect |
|---|---|
| `/sync` | `git pull --rebase`, then prints only new lines from others plus open tasks |
| `/claim <id>` | Locks the task; replies `TAKEN by @x` or `LOST RACE` if someone beat you, then pick another |
| `/handoff <id> <path:line>` | Marks done, logs `DONE`, pushes; optionally logs `UNBLOCKS` or `ASK` |

**Automatic notifications**
- At session start, `hk.sh sync` runs.
- On each prompt, `hk.sh peek` fetches (at most every 20 seconds) and prints `TEAM UPDATES` only if a teammate's board/log/decision lines changed. Your own lines are filtered out. No update means zero tokens added.
- The agent acts on an update only if it affects its task. It never replies to other agents.

**Rules baked into CLAUDE.md**
- Edit only directories you own. `contracts/` is the interface; change it only after an `ASK` or a decision line.
- Shared files (`package.json`, schema, env) need a `CLAIM-FILE` log line first.
- More than one round trip on anything means ask the human. No agent-to-agent loops.
- One person is the integrator in the last two hours and runs `/ship`.

**Tested** with two simulated teammates against a local remote: claim locking, a stale clone pushing correctly, concurrent log appends merging cleanly, event notification, and two people claiming the same task at the same instant (one wins, the other is told).

**Known limits**
- It needs a shared remote (GitHub) and everyone running `init` once.
- Notifications arrive at the next prompt, not mid-turn.
- If two people edit the same file anyway, you get a normal git conflict. `/sync` will report it.
- `hk.sh` uses bash and standard tools. It should work on macOS and Linux; I tested on Linux only.

---

## 6. Customising

| Want to... | Do this |
|---|---|
| Use Netlify, Railway, Render or another host | Remove `vercel` from `.mcp.json`; adjust step 4 of `/kickoff` and step 1 of `/ship` |
| Cut MCP token overhead further | Remove `github` and use the `gh` CLI or plain git |
| Stronger UI polish | Use the `frontend-design` skill for UI work and `dataviz` for charts and dashboards |
| Build a pitch deck | Use the `pptx` skill or a Slides artifact from `/pitch` output |
| Team of several people | Commit `.claude/` and `.hackathon/` so everyone shares the same rules; give each person a different slice in `PLAN.md` |
| Different tone or rules | Edit `CLAUDE.md`. Keep it short; every line is paid for on every turn |

---

## 7. Troubleshooting

| Symptom | Fix |
|---|---|
| Ponytail does nothing, no errors | Node isn't on the PATH that Claude Code sees. Install it or fix PATH, restart `claude` |
| `/plugin` not recognised | Claude Code is out of date. Update it and restart |
| Plugin not enabled after copy | Run the two `/plugin` commands in step 3, then `/reload-plugins` |
| `/mcp` shows github or vercel disconnected | Re-run sign-in from `/mcp` |
| Playwright fails on first run | Browser download is pending; retry, or run `npx playwright install chromium` |
| `Run: hk.sh init <yourname>` | Each person must run init once so claims and filters know who they are |
| Push blocked by pre-push | The project's `npm run check` failed; fix it, or `HK_SKIP=1 git push` in an emergency |
| `SYNC CONFLICT` | Resolve the files, `git rebase --continue`, rerun `/sync` |
| Clock line missing | `.hackathon/deadline` is missing or not in `YYYY-MM-DDTHH:MM` format |
| Agent is too terse or skips things you want | Say `stop ponytail` for that task, or relax the relevant line in `CLAUDE.md` |
| Context filling up | `/compact` at a milestone; `/clear` between unrelated tasks |

---

## 8. Limits to know about

- Ponytail's headline numbers are from the maker's benchmark; the independent result was smaller.
- Ponytail's live metrics board doesn't show in the VS Code chat panel, cloud sessions, or `claude -p`. The rules still apply there.
- I verified the config files parse and the clock hook prints correctly. I haven't run the whole harness inside a live Claude Code session, so test `/kickoff` once before the event starts.
- The `// FAKE:` convention only helps if you read the list before pitching. `/ship` includes it in the README.

---

## Sources
- Ponytail install and benchmarks: https://x-cmd.com/install/ponytail
- Independent JetBrains test: https://blog.jetbrains.com/ai/2026/07/ponytail-skill-claude-tested/
