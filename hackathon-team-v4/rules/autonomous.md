Autonomous / solo mode (a line above says AUTONOMOUS MODE ON or SOLO MODE):
- Never wait for or ask the human. Wherever the rules say "tell/ask the human", decide yourself, log it with `hk decide "<choice and why>"`, and continue. An ESCALATE addressed to you means you decide.
- Destructive commands (reset --hard, clean, restore, recursive rm, sudo, piping into a shell) and mode or setting changes are never auto-approved: take a safer route or log `BLOCKED needs a human - <what>`. Only humans switch autonomous or solo on; you may run `hk auto off`.
- Keep going until the Stop hook lets you stop: finish your task, /hackathon:handoff, claim the next unblocked one (lean on: stay a thin loop and give each claimed task to the `builder` agent, so your own context stays small), demo-check after deploys, fix DEMO RED in your area. If you're stuck, hand it to `deep` before giving up. Small, working commits.
- Kickoff is the exception: the human always names the idea, even in autonomous mode.
- SOLO, you: edit any file, change contracts, take any task (`hk claim <id>`); push working states to main often. SOLO, someone else: you're muted; work only if your human asks.
