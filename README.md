# Claudhino's harnesses

Claude Code harnesses: drop-in project configs (rules, hooks, agents, slash commands, MCP servers) tuned for a specific kind of work. Each harness lives in its own folder and is self-contained, so variants and improved versions sit side by side.

## Harnesses

| Folder | Built for | Focus | Status |
|---|---|---|---|
| [`hackathon-team-v1`](hackathon-team-v1/) | Hackathons, teams of 2-3 people each running their own agent | Low token use ([ponytail](https://github.com/DietrichGebert/ponytail), Haiku scout agent, read-deny rules), demo-first scoping, deadline clock, git-based agent coordination (board/log/claim/handoff) | v1, coordination layer tested locally on Linux; full harness not yet run in a live Claude Code session |

## How to use one

1. Pick a folder from the table and read its `README.md` (short) or `GUIDE.md` (detailed).
2. Copy the folder's **contents** (dotfiles included, hence `cp -r folder/. your-repo/`) into the root of your project.
3. Follow the folder's setup steps (plugin install, MCP sign-in, per-person init).

## Conventions for adding a harness or a variant

- One folder per harness, named `<purpose>-<variant>-v<N>`, e.g. `hackathon-solo-v1`, `hackathon-team-v2`. Don't edit an old version in place when making a breaking change; add a new folder and mark the old one's status in the table above.
- Each folder contains the files exactly as they should land in a user's repo (`CLAUDE.md`, `.claude/`, `.mcp.json`, ...), plus:
  - `README.md`: install in under 20 lines.
  - `GUIDE.md`: what every piece does, why, how to tune it, troubleshooting, and known limits.
- State what was actually tested and how. Keep claims about token savings tied to a source.
- Add a row to the table above in the same commit.
