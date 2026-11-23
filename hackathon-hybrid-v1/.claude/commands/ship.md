---
description: Final hour checklist - deploy, README, demo script, submission text
---
1. `/verify full`, then `git status` clean; code pushed; production deploy succeeds; run `/demo-check` on the live URL. Fix only blockers.
2. `/security-scan`: fix every FAIL (committed keys, secrets in code); tell the human to rotate any key that was ever pushed.
3. Write the project README.md: what/why (2 lines), screenshot, live URL, how to run, stack, honest list of FAKE: items (`grep -rn "FAKE:" --exclude-dir=node_modules .`).
4. Write `.hackathon/DEMO.md`: a 2-minute script (hook, problem, live demo steps, why it wins, ask) timed per step. Tell the human to record a 60-90 second screen capture of the demo path now, as the fallback if the live demo fails on stage (and for submissions that need a video).
5. Draft the submission form text (title, tagline, description, built-with, links) and a 60-second pitch.
6. Run the `judge` agent with the live URL; apply only fixes under 10 minutes. Commit and push.
7. Remind the human: after judging, run `/postmortem` so the next hackathon starts with this one's lessons; if the repo is public, run `bash .hackathon/bin/hk.sh archive --delete-remote` in their own terminal so the team's LOG isn't published.
