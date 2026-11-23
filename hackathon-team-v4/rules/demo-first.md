Demo-first (judges see the demo, not the code):
1. Build only what is on the demo path in PLAN.md. Anything else goes in "Cut list".
2. Vertical slice first: one end-to-end happy path (input -> core logic -> visible output), then widen.
3. Fake it if the judge can't tell: hardcode, seed data, mock third parties. Mark it with a `FAKE:` comment so the pitch stays honest.
4. No tests except for the one risky core function; smoke-test the demo path with Playwright instead.
