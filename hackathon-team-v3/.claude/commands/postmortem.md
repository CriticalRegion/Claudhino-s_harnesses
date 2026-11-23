---
description: After the event - record what happened and save lessons that every future /kickoff reads
argument-hint: [result, judges' feedback, anything that broke]
---
Notes: $ARGUMENTS
1. If the notes don't cover them, ask the human at most 3 short questions: the result (placed? which prizes?), what the judges or winners said, and what cost the most time.
2. Read `.hackathon/PLAN.md`, `.hackathon/RESEARCH.md` (if any), `.hackathon/state/LOG.md` and `git log --oneline | head -50` to see what actually happened: the idea, the stack, when the demo first went green, BLOCKED and ESCALATE lines.
3. Write `.hackathon/POSTMORTEM.md`: result; why we won or lost (in the judges' terms); what worked; what wasted time; the winning projects and why they won.
4. Save 3-6 lessons, each a single line that says what to do or avoid next time and why, for example `bash .hackathon/bin/hk.sh lesson "Judges marked down a polished strategy game as unoriginal; winners solved practical real-world problems. Pick a real problem first."`. Only lessons that would change a decision at a future event; no generic advice.
5. Commit POSTMORTEM.md and tell the human: the lessons saved, and that teammates should save the same lessons on their machines (or run /postmortem themselves).
