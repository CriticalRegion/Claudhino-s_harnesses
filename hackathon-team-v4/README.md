# Hackathon Team Harness (v4, Claude Code plugin)
A Claude Code plugin for hackathon teams of 1-4 people, each with their own agent: a setup interview per event, Opus ideation (switchable: bring your own idea) and a lean plan, demo-first rules (switchable), a deadline clock, a git-based team board whose events reach agents mid-task or wake them, autonomous and solo modes, a **night shift** (agents build, critique each other's work and merge toward a goal while you sleep), a safety guard and stop check you can switch on, a Discord feed and a usage log. **Toggleable per project**: pause it instantly or turn it off and Claude is normal again. Details: [GUIDE.md](GUIDE.md).

## Install (once per machine; Claude Code >= 2.1.324, git, bash, Node.js; Windows: Git for Windows)
```
/plugin marketplace add CriticalRegion/Claudhino-s_harnesses
/plugin install hackathon@claudhino
```
## Every hackathon
1. In the project (a git repo with a remote): `/hackathon:setup` - the interview: event, deadline, judging criteria, team; profile (**sprint** / **crunch** / **careful**) and any toggles; Discord. It installs the project pieces, joins or creates the team board and commits.
2. `/hackathon:research <event URL>` (optional), then `/hackathon:kickoff` - ideas on Opus, scored by the `judge`; **you pick**, then a lean plan and the first board task.
3. Build: `/hackathon:slice`, `/hackathon:sync`, `/hackathon:claim <id>`, `/hackathon:handoff <id> <path:line>`, `/hackathon:demo-check`.
4. Last hour: `/hackathon:ship`. Afterwards: `/hackathon:postmortem` (lessons every future kickoff reads).

Teammates: install the plugin, open the project, run `/hackathon:setup` (only asks their name and Discord).

## Switches
| | |
|---|---|
| `/hackathon:pause` / `resume` | Instant, this clone only: no rules, hooks, wake-ups or git-hook checks |
| `/hackathon:off` | Disables the plugin for this project (then `/reload-plugins`); `/plugin enable hackathon@claudhino` brings it back |
| `hk config profile sprint\|crunch\|careful`, `hk config set k=v` | Team settings (all listed by `hk config show`) |
| `hk demo-first off` | Build it properly instead of demo-first |
| `hk config set ideation=off` | Bring your own idea: kickoff skips idea generation and just plans it |
| `.hackathon/bin/hk auto on 2h` / `solo @name` | Autonomous / solo mode: humans only, in your own terminal; `hk auto off` is the kill switch |
| `/hackathon:night <goal>` then `.hackathon/bin/hk night start --until 07:00 --budget 30` | Night shift: the agents build on branches, review each other (numbered MUST/SHOULD findings, capped rounds), merge what's approved and run goal checks until the Done-when list passes or time/budget runs out; `hk night report` in the morning, `hk night stop` any time |
| `hk discord <webhook> --global` | Post every event to a Discord forum, one post per hackathon |

## Commands
`setup` `research` `kickoff` `pivot` `slice` `sync` `claim` `handoff` `verify` `build-fix` `checkpoint` `demo-check` `cut` `pitch` `ship` `security-scan` `cost` `status` `postmortem` `pause` `resume` `off` `night` `review` `goal-check` (all `/hackathon:<name>`). Agents: `scout` (Haiku), `judge` (Opus), `deep` (Opus escalation), `build-fixer`, `reviewer`, `critic` (night-shift reviews).

## Test it
`bash hackathon-team-v4/tests/run.sh` - 625 end-to-end checks (the engine, events, races, offline, modes, the night shift, guard, monitor, stop check, settings, pause/off, rules injection, usage log, v3 migration, the launcher), run in CI on Linux, macOS and Windows. Setup, kickoff, pause/resume and a plugin-less session were also checked live in Claude Code. Builds on v3.1 and hackathon-hybrid-v1 (see GUIDE section 12); parts adapted from [ECC](https://github.com/affaan-m/ECC) (MIT, [notices](THIRD_PARTY_NOTICES.md)).
