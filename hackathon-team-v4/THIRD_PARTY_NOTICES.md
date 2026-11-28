# Third-party notices

## Anthropic frontend-design skill
`skills/frontend-design/SKILL.md` is Anthropic's frontend-design skill, copied unchanged from
https://github.com/anthropics/skills (skills/frontend-design, commit e4bb5d9). It is licensed under the Apache License 2.0;
the full licence is in `skills/frontend-design/LICENSE.txt`. The `designer` agent reads it with `hk skill frontend-design`.

## unslop skill
`skills/unslop/` is the unslop skill by Damir Sokolovsky (@heydamir), https://github.com/heydamir/unslop (commit 620163e),
copied unchanged (the licence file added alongside it as `skills/unslop/LICENSE`). It is licensed under Creative Commons
Attribution 4.0 International (CC BY 4.0, https://creativecommons.org/licenses/by/4.0/); the licence text is in
`skills/unslop/LICENSE`. The harness changes nothing in it. The `designer` agent reads it with `hk skill unslop`;
`/hackathon:design unslop` runs it inside the locked design.

## ECC (Everything Claude Code)
Parts of this plugin are adapted from ECC, https://github.com/affaan-m/ECC: the destructive-command classifier
(GateGuard), block-no-verify, config protection, the dev-server block, strategic compaction, the context monitor and
loop warning, the batched stop typecheck, desktop notifications and the statusline (all in `bin/hh.js`, ported from
the Claudhino team's hackathon-hybrid-v1), the `build-fixer`, `reviewer` and `judge` agents (adapted from ECC's
build-error-resolver, code-reviewer and gan-evaluator), and the `/hackathon:verify`, `checkpoint`, `build-fix` and
`security-scan` commands. ECC's licence:

    MIT License

    Copyright (c) 2026 Affaan Mustafa

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
