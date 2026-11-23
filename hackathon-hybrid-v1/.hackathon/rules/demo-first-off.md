# Build-it-properly rules (demo-first OFF). hk.sh prints these at session start only while the switch is off.
1. Read `.hackathon/PLAN.md` first. Build complete features in milestone order, not just the demo path.
2. No new `FAKE:` stubs or mocks; when you touch code that has one, replace it with the real thing.
3. Handle errors and edge cases; validate inputs.
4. Write tests for the logic you add, and run them before committing (`/verify`).
