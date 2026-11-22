# Claudhino's harnesses

Claude Code harnesses: drop-in project configs (rules, hooks, agents, slash commands, MCP servers) tuned for a specific kind of work. Each harness lives in its own folder and is self-contained, so variants and improved versions sit side by side.

## Harnesses

| Folder | Built for | Focus | Status |
|---|---|---|---|
| [`hackathon-team-v2`](hackathon-team-v2/) | Hackathons, teams of 2-4 people each running their own agent | Same as v1, with coordination on its own git branch (never pushes your code), honest offline handling, row-wise board merges, non-destructive `install.sh`, pinned plugin/MCP versions | v2, current. 82 end-to-end tests (`tests/run.sh`) on Linux; hooks, MCP and subagents verified in a live headless Claude Code 2.1.325 session; macOS untested |
| [`hackathon-team-v1`](hackathon-team-v1/) | Hackathons, teams of 2-3 | Original version | Superseded by v2: board commands push unfinished code to main, report success when offline, and the install overwrites README/.gitignore (see v2 GUIDE, "Changes from v1") |

## How to use one

1. Pick a folder from the table and read its `README.md` (short) or `GUIDE.md` (detailed).
2. Install it into your project: `bash <folder>/install.sh your-repo` if the folder has an installer (v2+), otherwise copy the folder's **contents** (dotfiles included: `cp -r folder/. your-repo/`) and merge by hand anything you already have.
3. Follow the folder's setup steps (plugin install, MCP sign-in, per-person init).

## Conventions for adding a harness or a variant

- One folder per harness, named `<purpose>-<variant>-v<N>`, e.g. `hackathon-solo-v1`, `hackathon-team-v2`. Don't edit an old version in place when making a breaking change; add a new folder and mark the old one's status in the table above.
- Each folder contains the files exactly as they should land in a user's repo (`CLAUDE.md`, `.claude/`, `.mcp.json`, ...), plus:
  - `README.md`: install in under 20 lines.
  - `GUIDE.md`: what every piece does, why, how to tune it, troubleshooting, and known limits.
- State what was actually tested and how. Keep claims about token savings tied to a source.
- Add a row to the table above in the same commit.
