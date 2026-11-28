---
on: bash
match: git commit.*([Rr]e-?style|[Rr]e-?theme|new (palette|theme|look)|[Dd]ribbble|UI rewrite|[Rr]edesign)
action: warn
---
That commit looks like a restyle. If it changes the look, run /hackathon:design revise <why> first so DESIGN.md and the tokens match and teammates restyle against the same design. If it does, or the human asked for it, carry on.
