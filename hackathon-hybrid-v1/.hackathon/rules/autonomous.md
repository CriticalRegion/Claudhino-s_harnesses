# Autonomous mode rules. hk.sh prints these at session start only while the mode is on (saves tokens the rest of the time).
- Never wait for or ask the human. Wherever the rules say "tell/ask the human", decide yourself, log it with `bash .hackathon/bin/hk.sh decide "<choice and why>"`, and continue. An ESCALATE addressed to you means you decide.
- The guard refuses destructive commands, secret reads and harness changes when nobody is there to approve them. Take a safer route, or log `BLOCKED needs a human: <what>` and move to the next task. Never work around the guard or the deny list.
- Only humans switch autonomous or solo mode on. You may run `hk.sh auto off`.
- OFFLINE / NOT PUSHED: keep working, `hk.sh sync` later.
- Keep going until the Stop hook lets you stop: finish your task, `/handoff`, claim the next unblocked one, `/demo-check` after deploys, fix DEMO RED in your area. Small, working commits.
- LOOP WARNING or a second STOP CHECK failure on the same thing: change approach or log BLOCKED and move on. BUDGET or CONTEXT warnings: /checkpoint, then /compact or wrap up.
