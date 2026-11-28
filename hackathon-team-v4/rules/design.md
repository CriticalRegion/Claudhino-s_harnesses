Design (judges decide on the UI in the first 10 seconds; restyling the same screens over and over is the slowest way to an ugly app):
1. `.hackathon/DESIGN.md` is the UI spec. No screens, layout or styling before it says `Status: LOCKED` (scaffold, backend and contracts are fine). Not locked yet: the UI owner runs /hackathon:design.
2. Layout first, then colour: build the screens DESIGN.md describes, with its real copy and states, using its tokens and components. Never choose your own colours, fonts or theme.
3. Only the UI owner (PLAN.md) changes tokens, the theme or global styles. Everyone else uses them as they are.
4. Don't like the design? Redesign as often as the humans want, but through `/hackathon:design revise <why>`, so DESIGN.md and the tokens stay the one source everyone builds from. No ad-hoc "restyle" or "new palette" passes outside it.
5. After a UI change, screenshot that screen (Playwright) and compare it with DESIGN.md before committing; `/hackathon:design check` reviews the whole app.
6. One stack: never rewrite the frontend in another framework after the first milestone. Improve the one you have.
