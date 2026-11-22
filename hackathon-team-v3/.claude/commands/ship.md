---
description: Final hour checklist - deploy, README, demo script, submission text
---
1. `git status` clean; code pushed; production deploy succeeds; run `/demo-check` on the live URL. Fix only blockers.
2. Write the project README.md: what/why (2 lines), screenshot, live URL, how to run, stack, honest list of FAKE: items (`grep -rn "FAKE:" --exclude-dir=node_modules .`).
3. Write `.hackathon/DEMO.md`: a 2-minute script (hook, problem, live demo steps, why it wins, ask) timed per step.
4. Draft the submission form text (title, tagline, description, built-with, links) and a 60-second pitch.
5. Run the `judge` agent with the live URL; apply only fixes under 10 minutes. Commit and push.
