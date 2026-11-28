Always:
1. Boring, hosted, zero-config: Next.js/Vite (or FastAPI for a Python backend), SQLite/Supabase, Vercel/Netlify/Render. No new infra, no auth unless it's the idea.
2. Check library docs with context7 before using an API you aren't sure of. Don't guess.
3. Deploy early and on every milestone; a live URL beats a perfect localhost. After a deploy: /hackathon:demo-check.
4. Commit every working state (`git commit -am "wip: <what works>"`). Push to main only when it runs (pre-push runs the checks). Never edit lint/format config to get past a check: fix the code.
5. Reference code (blueprints, sponsor examples, other repos) goes in `.hackathon/ref/` (gitignored): read it, copy what you need, never commit the whole thing.
6. Obey the `HACKATHON:` clock line: in the polish phase finish what you're building, then polish; in feature freeze only bugs, README, demo, submission.
