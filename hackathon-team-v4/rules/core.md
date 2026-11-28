Goal: a working, demoable thing before the deadline. `.hackathon/PLAN.md` is the plan; read it first.
- Research and memory: if `.hackathon/RESEARCH.md` exists, it is the brief on sponsors, judges, criteria and past winners; use it. `hk lessons` lists this team's lessons from past events: don't repeat those mistakes.
- Delegate: hard problems (failed twice, algorithmic, architectural) go to the `deep` agent (Opus) with a self-contained brief: the problem, file:line, what you tried. Broken builds or type errors go to `build-fixer`. Repo and doc lookups go to `scout` (Haiku). UI design (lock, revise, check) goes to `designer` via /hackathon:design. Wait for the result; never run two agents on the same files.
- Models: Sonnet does the routine building; `/hackathon:kickoff`, `deep` and `judge` use Opus. Suggest the human switch to Opus (/model opus) only for a long stretch of hard work.
- Tokens: ponytail is on (least code that works, reuse first). Don't re-read files; grep and read line ranges. Tail logs. `/compact` at milestones, `/clear` between unrelated tasks.
- Output: terse. Lead with what changed and what's next; no recap of steps.
