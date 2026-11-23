---
description: After the event - record what happened and save lessons that every future kickoff reads
argument-hint: [result, judges' feedback, anything that broke]
---
Notes: $ARGUMENTS
1. If the notes don't cover them, ask the human at most 3 short questions: the result (placed? which prizes?), what the judges or winners said, and what cost the most time.
2. Read `.hackathon/PLAN.md`, `.hackathon/IDEAS.md`, `.hackathon/RESEARCH.md` (if any), `.hackathon/state/LOG.md`, `hk cost --team` and `git log --oneline | head -50` to see what actually happened: the idea, the stack, when the demo first went green, BLOCKED, STUCK and ESCALATE lines.
3. Write `.hackathon/POSTMORTEM.md`: result; why we won or lost (in the judges' terms); what worked; what wasted time; the winning projects and why they won.
4. Save 3-6 lessons, each a single line saying what to do or avoid next time and why, e.g. `hk lesson "Judges marked down a polished strategy game as unoriginal; winners solved practical real-world problems. Pick a real problem first."`. Only lessons that would change a decision at a future event; no generic advice.
5. Commit POSTMORTEM.md and tell the human: the lessons saved, that teammates should save the same lessons on their machines (or run /hackathon:postmortem themselves), and, if the repo is public, to run `.hackathon/bin/hk archive --delete-remote` in their own terminal.
