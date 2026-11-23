#!/usr/bin/env node
// hh.js - safety guard, context/loop/cost monitor, stop check, handoff, notifications, statusline
// and security scan for the hackathon hybrid harness. One file, no dependencies, Node >= 16.
//
//   node hh.js guard        PreToolUse   gate destructive / secret / harness-tampering commands and edits
//   node hh.js post         PostToolUse  edited-file log, loop warnings, context % and budget warnings
//   node hh.js stop         Stop         check files edited this turn (tsc/py/js/json), handoff, notify
//   node hh.js prompt       UserPromptSubmit  mark the turn start (for notifications)
//   node hh.js precompact   PreCompact   save a handoff snapshot before compaction
//   node hh.js start        SessionStart print the handoff after compact/resume/clear
//   node hh.js statusline   statusLine   deadline | @me task | mode | demo | ctx % | cost
//   node hh.js scan         CLI          deterministic pre-submission security scan
//   node hh.js check "<cmd>" [--auto]   CLI: show what the guard decides for a shell command
//
// Ideas adapted from ECC (https://github.com/affaan-m/ECC, MIT licence, (c) 2026 Affaan Mustafa):
// GateGuard's tokenising destructive-command classifier, block-no-verify, config-protection,
// the dev-server block, strategic compaction, the context monitor's loop warning, the batched
// Stop typecheck, desktop notifications and the statusline. Rewritten small for this harness.
// ECC's licence, which covers the adapted parts:
//   MIT License
//
//   Copyright (c) 2026 Affaan Mustafa
//
//   Permission is hereby granted, free of charge, to any person obtaining a copy
//   of this software and associated documentation files (the "Software"), to deal
//   in the Software without restriction, including without limitation the rights
//   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//   copies of the Software, and to permit persons to whom the Software is
//   furnished to do so, subject to the following conditions:
//
//   The above copyright notice and this permission notice shall be included in all
//   copies or substantial portions of the Software.
//
//   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//   SOFTWARE.
'use strict';
const fs = require('fs'), path = require('path'), os = require('os'), cp = require('child_process'), crypto = require('crypto');

const ROOT = process.env.HH_ROOT || path.resolve(__dirname, '..', '..');
const H = path.join(ROOT, '.hackathon'), HH = path.join(H, '.hh'), WT = path.join(H, 'state');
const env = process.env;
const off = v => /^(0|off|false|no|disabled)$/i.test(String(v || '').trim());
const num = (v, d) => { const x = Number(v); return Number.isFinite(x) && String(v).trim() !== '' ? x : d; };
const rd = f => { try { return fs.readFileSync(f, 'utf8'); } catch { return ''; } };
const wr = (f, s) => { try { fs.mkdirSync(path.dirname(f), { recursive: true }); fs.writeFileSync(f, s); } catch {} };
const jread = (f, d) => { try { return JSON.parse(fs.readFileSync(f, 'utf8')); } catch { return d; } };
const sha = s => crypto.createHash('sha1').update(String(s)).digest('hex').slice(0, 12);
const ME = () => (rd(path.join(H, '.me')).trim() || env.HK_ME || '').toLowerCase();
const sid = i => String((i && i.session_id) || 'nosession').replace(/[^\w-]/g, '').slice(0, 64) || 'nosession';
const out = o => process.stdout.write(JSON.stringify(o) + '\n');
const slash = p => String(p).replace(/\\/g, '/');
function stdin() {
  try { if (process.stdin.isTTY) return {}; const s = fs.readFileSync(0, 'utf8'); return s.trim() ? JSON.parse(s) : {}; }
  catch { return {}; }
}
function run(cmd, args, opt) {
  const r = cp.spawnSync(cmd, args, Object.assign({ cwd: ROOT, encoding: 'utf8', timeout: 15000, windowsHide: true,
    shell: process.platform === 'win32' && /^(npx|npm|pnpm|yarn)$/.test(cmd) }, opt || {}));
  return { code: r.status, out: (r.stdout || '') + (r.stderr || ''), err: r.error };
}
const git = (...a) => { const r = run('git', ['-C', ROOT, ...a], { timeout: 8000 }); return r.code === 0 ? r.out.trim() : ''; };

// ---------- modes (mirrors hk.sh eff_auto) ----------
function modeTable() {
  const t = {};
  for (const l of rd(path.join(WT, 'MODE.md')).split('\n')) {
    const p = l.split('|'); if (p.length < 4) continue;
    const k = p[1].trim(), v = p[2].trim(); if (k && k !== 'id' && !/^-+$/.test(k)) t[k] = v;
  }
  return t;
}
function minsLeft() {
  const d = rd(path.join(H, 'deadline')).split('\n')[0].replace(/\r/g, '').trim();
  const m = d.match(/^(\d{4})-(\d\d)-(\d\d)[T ](\d\d):(\d\d)/); if (!m) return null;
  return Math.floor((new Date(+m[1], m[2] - 1, +m[3], +m[4], +m[5]).getTime() - Date.now()) / 60000);
}
function autoOn() {
  if (env.HK_TEST_AUTO) return env.HK_TEST_AUTO === '1';
  const m = minsLeft(); if (m !== null && m <= 0) return false;
  const t = modeTable(), solo = t.solo || '-', loc = rd(path.join(H, '.auto')).trim().split(/\s+/), me = '@' + ME();
  let u;
  if (solo !== '-' && solo !== '') { if (solo !== me || loc[0] === 'off') return false; u = num(t.solo_until, 0); }
  else if (loc[0]) { if (loc[0] !== 'on') return false; u = num(loc[1], 0); }
  else { if (t.auto !== 'on') return false; u = num(t.auto_until, 0); }
  return !(u && Date.now() / 1000 >= u);
}
function demoFirstOff() { const l = rd(path.join(H, '.demofirst')).trim() || modeTable().demo_first || 'on'; return l === 'off'; }

// ---------- shell parsing (quote-aware; substitutions, heredocs, wrappers) ----------
function readBalanced(s, i) { // s[i] is just after "(": return [body, index of matching ")"]
  let d = 1, j = i, q = null;
  for (; j < s.length; j++) {
    const c = s[j];
    if (q) { if (c === '\\' && q === '"') { j++; continue; } if (c === q) q = null; continue; }
    if (c === '\\') { j++; continue; }
    if (c === '"' || c === "'" || c === '`') { q = c; continue; }
    if (c === '(') d++; else if (c === ')' && --d === 0) break;
  }
  return [s.slice(i, j), j];
}
function parseShell(src) {
  src = String(src || '');
  const cmds = [], heredocs = []; let pipeline = 0, i = 0, word = null, pending = null;
  const mk = piped => ({ argv: [], assign: [], redirs: [], pipedIn: piped, pipeline, bg: false, subs: [], procsubs: [], heredocs: [] });
  let cur = mk(false);
  const add = s => { word = (word === null ? '' : word) + s; };
  const endWord = () => {
    if (word === null) return;
    if (pending) { cur.redirs.push({ op: pending, target: word }); pending = null; }
    else if (!cur.argv.length && /^[A-Za-z_][A-Za-z0-9_]*=/.test(word)) cur.assign.push(word);
    else cur.argv.push(word);
    word = null;
  };
  const endCmd = op => {
    endWord(); pending = null;
    if (op === '&') cur.bg = true;
    if (cur.argv.length || cur.redirs.length || cur.assign.length) cmds.push(cur);
    if (op === '|') cur = mk(true); else { pipeline++; cur = mk(false); }
  };
  const n = src.length;
  while (i < n) {
    const c = src[i], c1 = src[i + 1];
    if (c === '\\') { if (c1 === '\n') { i += 2; continue; } add(c1 || ''); i += 2; continue; }
    if (c === "'") { const e = src.indexOf("'", i + 1), j = e < 0 ? n : e; add(src.slice(i + 1, j)); i = j + 1; continue; }
    if (c === '"') {
      let j = i + 1, s = '';
      while (j < n && src[j] !== '"') {
        if (src[j] === '\\' && '"\\$`\n'.includes(src[j + 1])) { s += src[j + 1]; j += 2; continue; }
        if (src[j] === '$' && src[j + 1] === '(' && src[j + 2] !== '(') { const [b, e] = readBalanced(src, j + 2); cur.subs.push(b); s += '$(..)'; j = e + 1; continue; }
        if (src[j] === '`') { const e = src.indexOf('`', j + 1), k = e < 0 ? n : e; cur.subs.push(src.slice(j + 1, k)); s += '`..`'; j = k + 1; continue; }
        s += src[j]; j++;
      }
      add(s); i = j + 1; continue;
    }
    if (c === '$' && c1 === '(' && src[i + 2] !== '(') { const [b, e] = readBalanced(src, i + 2); cur.subs.push(b); add('$(..)'); i = e + 1; continue; }
    if (c === '`') { const e = src.indexOf('`', i + 1), k = e < 0 ? n : e; cur.subs.push(src.slice(i + 1, k)); add('`..`'); i = k + 1; continue; }
    if ((c === '<' || c === '>') && c1 === '(') { const [b, e] = readBalanced(src, i + 2); endWord(); cur.subs.push(b); cur.procsubs.push(b); cur.argv.push('/dev/fd/63'); i = e + 1; continue; }
    if (c === '#' && word === null) { const e = src.indexOf('\n', i); i = e < 0 ? n : e; continue; }
    if (c === ' ' || c === '\t' || c === '\r') { endWord(); i++; continue; }
    if (c === '\n') {
      endCmd(';'); i++;
      while (heredocs.length) {
        const h = heredocs.shift(), lines = [];
        while (i < n) {
          let e = src.indexOf('\n', i); if (e < 0) e = n;
          const line = src.slice(i, e); i = e + 1;
          if ((h.strip ? line.replace(/^\t+/, '') : line).replace(/\r$/, '') === h.delim) break;
          lines.push(line);
        }
        h.cmd.heredocs.push(lines.join('\n'));
      }
      continue;
    }
    if (c === ';') { endCmd(';'); i += c1 === ';' ? 2 : 1; continue; }
    if (c === '&') {
      if (c1 === '&') { endCmd('&&'); i += 2; continue; }
      if (c1 === '>') { endWord(); pending = '>'; i += src[i + 2] === '>' ? 3 : 2; continue; }
      endCmd('&'); i++; continue;
    }
    if (c === '|') { if (c1 === '|') { endCmd('||'); i += 2; continue; } endCmd('|'); i += c1 === '&' ? 2 : 1; continue; }
    if (c === '(' || c === ')') { endCmd(';'); i++; continue; }
    if (c === '<' || c === '>') {
      if (word !== null && /^\d+$/.test(word)) word = null; else endWord();
      if (c === '<' && c1 === '<' && src[i + 2] === '<') { pending = '<<<'; i += 3; continue; }
      if (c === '<' && c1 === '<') {
        let j = i + 2, strip = false, d = '';
        if (src[j] === '-') { strip = true; j++; }
        while (src[j] === ' ' || src[j] === '\t') j++;
        while (j < n && !/[\s;|&<>()]/.test(src[j])) {
          if (src[j] === "'" || src[j] === '"') { const q = src[j], e = src.indexOf(q, j + 1), k = e < 0 ? n : e; d += src.slice(j + 1, k); j = k + 1; continue; }
          if (src[j] === '\\') { d += src[j + 1] || ''; j += 2; continue; }
          d += src[j]; j++;
        }
        heredocs.push({ delim: d, strip, cmd: cur }); i = j; continue;
      }
      let op = c; i++;
      if (c === '>' && src[i] === '>') { op = '>>'; i++; } else if (src[i] === '|') i++;
      if (src[i] === '&') { i++; while (i < n && /[\d-]/.test(src[i])) i++; continue; }   // 2>&1
      pending = op; continue;
    }
    if ((c === '{' || c === '}') && word === null && (i + 1 >= n || /[\s;]/.test(c1))) { i++; continue; }
    add(c); i++;
  }
  endCmd(';');
  return cmds;
}
const base = w => slash(w || '').split('/').pop().toLowerCase().replace(/\.(exe|cmd|bat)$/, '');
const SHELLS = new Set(['sh', 'bash', 'zsh', 'dash', 'ksh', 'fish', 'ash', 'busybox']);
const INTERP = /^(python[\d.]*|py|node|nodejs|deno|bun|perl|ruby|php|pwsh|powershell)$/;
const VALUE_OPTS = {
  sudo: ['-u', '-g', '-h', '-p', '-C', '-T', '-r', '-t', '-U', '--user', '--group'], doas: ['-u', '-C'],
  env: ['-u', '-C', '--unset', '--chdir'], nice: ['-n', '--adjustment'], ionice: ['-c', '-n', '-t'],
  timeout: ['-s', '-k', '--signal', '--kill-after'], gtimeout: ['-s', '-k'], stdbuf: ['-i', '-o', '-e'],
  xargs: ['-n', '-I', '-P', '-L', '-d', '-E', '-s', '-a', '--max-args', '--max-procs', '--delimiter', '--arg-file'],
  watch: ['-n', '--interval'], exec: ['-a'], nohup: [], time: ['-f', '-o'], command: [], builtin: [], noglob: [],
  setsid: [], chronic: [], unbuffer: [],
};
// -> { argv, wrappers:[names], nested:[shell strings to analyse], envDump }
function unwrap(argv) {
  const wrappers = [], nested = []; let a = argv.slice(), envDump = false;
  for (let guard = 0; guard < 12 && a.length; guard++) {
    const w = base(a[0]);
    if (w === 'env' || w in VALUE_OPTS && w !== 'env') {
      wrappers.push(w); a = a.slice(1);
      if (w === 'command' && /^-[vV]$/.test(a[0] || '')) return { argv: [], wrappers, nested, envDump };
      const vals = VALUE_OPTS[w] || [];
      while (a.length && (a[0].startsWith('-') || (w === 'env' && /^[A-Za-z_]\w*=/.test(a[0])))) {
        if (w === 'env' && /^(-S|--split-string)/.test(a[0])) { const s = a[0].includes('=') ? a[0].split('=').slice(1).join('=') : a[1]; nested.push(s || ''); return { argv: [], wrappers, nested, envDump }; }
        if (a[0] === '--') { a = a.slice(1); break; }
        const takes = vals.includes(a[0]); a = a.slice(takes ? 2 : 1);
      }
      if ((w === 'timeout' || w === 'gtimeout') && a.length && /^[\d.]+[smhd]?$/.test(a[0])) a = a.slice(1);
      if (w === 'nice' && a.length && /^-?\d+$/.test(a[0])) a = a.slice(1);
      if (w === 'env' && !a.length) envDump = true;
      continue;
    }
    if (SHELLS.has(w)) {
      const k = a.findIndex((t, x) => x > 0 && /^-[a-zA-Z]*c[a-zA-Z]*$/.test(t));
      if (k > 0 && a[k + 1] !== undefined) { wrappers.push(w); nested.push(a[k + 1]); return { argv: [], wrappers, nested, envDump }; }
    }
    if (w === 'eval') { nested.push(a.slice(1).join(' ')); return { argv: [], wrappers, nested, envDump }; }
    break;
  }
  return { argv: a, wrappers, nested, envDump };
}

// ---------- path classes ----------
function rel(p, cwd) {
  let s = String(p || '').trim(); if (!s) return '';
  if (s === '~' || s.startsWith('~/')) s = path.join(os.homedir(), s.slice(1));
  return slash(path.relative(ROOT, path.resolve(cwd || ROOT, s)));
}
const SECRET_BASE = /^(\.env(\.(?!example$|sample$|template$|defaults$|dist$|schema$)[\w.-]+)?|\.envrc|.+\.pem|.+\.p12|.+\.pfx|.+\.key|id_(rsa|ed25519|ecdsa|dsa)(\.pub)?|\.npmrc|\.netrc|\.pypirc|\.git-credentials|credentials(\.json)?|service[-_]?account.*\.json|\.htpasswd|\.dev\.vars)$/i;
function isSecret(tok) {
  const t = slash(String(tok || '')).replace(/^["']|["']$/g, '');
  if (!t || t.length > 300) return false;
  if (/(^|\/)\.ssh\/|\.aws\/credentials|\.config\/gcloud\/|hackathon-harness\/discord|\.hackathon\/\.discord/.test(t)) return true;
  const b = t.split('/').pop();
  if (/\.pub$/.test(b)) return false;
  return SECRET_BASE.test(b) || (/[*?]/.test(b) && SECRET_BASE.test(b.replace(/[*?]+/g, '') + 'local'));
}
const STATE_RE = /^\.hackathon\/(state(\/|$)|\.me$|\.auto$|\.demofirst$|\.discord$|\.seen$|\.ucur$|\.lock|\.cur\.lock|\.wakes$|\.warned$|\.hh(\/|$))/;
const STATE_RAW = /\.hackathon\/state(\/|$)|hackathon-harness\/(LESSONS\.md|discord)/;
const HARNESS_RE = /^(\.claude\/(settings(\.local)?\.json|hooks(\/|$)|agents\/|commands\/)|\.githooks(\/|$)|\.hackathon\/(bin|rules)(\/|$)|\.mcp\.json$|\.github\/workflows\/|CLAUDE\.md$|AGENTS\.md$)/;
const LINT_RE = /(^|\/)(\.eslintrc(\.\w+)?|eslint\.config\.[cm]?[jt]s|\.prettierrc(\.\w+)?|prettier\.config\.[cm]?js|\.?biome\.jsonc?|\.?ruff\.toml|\.stylelintrc(\.\w+)?|stylelint\.config\.[cm]?[jt]s|\.markdownlint\.\w+|\.flake8|mypy\.ini|\.pylintrc|pyrightconfig\.json|\.golangci\.ya?ml|clippy\.toml|\.rubocop\.yml)$/;
const SAFE_DEL = /^(node_modules|\.next|dist|build|out|\.turbo|\.cache|coverage|__pycache__|\.pytest_cache|\.parcel-cache|\.svelte-kit|\.nuxt|\.output|\.vercel|target|\.expo|\.angular|tmp|\.tmp|\.mypy_cache|\.ruff_cache|storybook-static|\.vite|\.wrangler|\.playwright-mcp|playwright-report|test-results|venv|\.venv)$/;
function safeDelTarget(t, cwd) {   // build output, caches and dependency folders inside the project, or temp files outside it
  let s = slash(t).replace(/\/\*$/, ''); if (!s || /[*?]/.test(s)) return false;
  if (s === '~' || s.startsWith('~/')) s = path.join(os.homedir(), s.slice(1));
  const abs = path.resolve(cwd || ROOT, s), r = slash(path.relative(ROOT, abs));
  if (abs === path.resolve(ROOT)) return false;
  if (r.startsWith('..') || path.isAbsolute(r)) return [os.tmpdir(), '/tmp', '/var/tmp'].some(x => abs.startsWith(path.resolve(x) + path.sep));
  return r.split('/').some(seg => SAFE_DEL.test(seg));
}

// ---------- the guard: findings for a shell command ----------
// severities: 'deny' (always refused), 'gate' (ask the human; refused when nobody is there to ask)
const KNOWN_NPX = new Set(('create-next-app create-vite create-react-app vite next tsc typescript eslint prettier biome @biomejs/biome ' +
  'playwright @playwright/test @playwright/mcp vercel netlify netlify-cli prisma drizzle-kit supabase shadcn shadcn-ui tsx ts-node vitest jest ' +
  'serve http-server wrangler tailwindcss @tailwindcss/cli expo create-expo-app convex turbo nodemon degit giget sv create-svelte astro ' +
  'create-astro @angular/cli nuxi nuxt eas-cli firebase-tools @upstash/context7-mcp lighthouse knip depcheck npm-check-updates concurrently ' +
  'json-server create-t3-app @vercel/ncc esbuild rollup webpack webpack-cli parcel storybook sb @storybook/cli pnpm yarn npm corepack ' +
  'node-gyp @anthropic-ai/claude-code @modelcontextprotocol/inspector @tauri-apps/cli electron create-electron-app hardhat @remix-run/dev ' +
  'create-remix @sveltejs/kit svelte-check vue-tsc @vue/cli create-vue @nestjs/cli @redwoodjs/cli localtunnel ngrok').split(' '));
const DEV_SCRIPT = /^(dev|start|serve|preview|watch|develop|(dev|start|serve):[\w:-]+)$/;
function devServer(name, rest) {
  const first = rest.find(t => !t.startsWith('-')) || '';
  const has = (...w) => rest.some(t => w.includes(t));
  if (['npm', 'pnpm', 'yarn', 'bun'].includes(name)) {
    let k = 0; while (k < rest.length && rest[k].startsWith('-')) k++;
    let s = rest[k] || ''; if (s === 'run' || s === 'run-script') s = rest[k + 1] || '';
    if (s === 'dlx' || s === 'exec' || s === 'x') return devServer(base(rest[k + 1] || ''), rest.slice(k + 2));
    if (name === 'npm' && !['start', 'run', 'run-script'].includes(rest[k] || '') && s !== 'start') return false;
    return DEV_SCRIPT.test(s);
  }
  if (name === 'npx' || name === 'bunx') { const r = rest.filter(t => !/^(-y|--yes)$/.test(t)); return devServer(base(r[0] || '').replace(/@[^/]*$/, ''), r.slice(1)); }
  if (name === 'next' || name === 'nuxi' || name === 'nuxt' || name === 'astro' || name === 'remix') return ['dev', 'start'].includes(first);
  if (name === 'vite') return !['build', 'optimize'].includes(first);
  if (['nodemon', 'live-server', 'http-server', 'serve', 'json-server', 'uvicorn', 'gunicorn', 'hypercorn', 'daphne'].includes(name)) return true;
  if (name === 'wrangler' || name === 'convex') return first === 'dev';
  if (name === 'expo') return first === 'start';
  if (name === 'flask') return first === 'run';
  if (name === 'fastapi') return first === 'dev' || first === 'run';
  if (name === 'streamlit') return first === 'run';
  if (name === 'rails') return ['s', 'server'].includes(first);
  if (name === 'php') return has('-S') || (first === 'artisan' && rest.includes('serve'));
  if (name === 'hugo') return first === 'server' || first === 'serve';
  if (name === 'jekyll') return first === 'serve';
  if (name === 'ngrok' || name === 'cloudflared' || name === 'lt') return true;
  if (/^python/.test(name)) { const m = rest.indexOf('-m'); if (m >= 0) return /^(http\.server|flask|uvicorn|streamlit|gradio)$/.test(rest[m + 1] || '') && !(rest[m + 1] === 'flask' && rest[m + 2] !== 'run'); return rest.includes('runserver'); }
  if (name === 'docker' || name === 'docker-compose') { const r = name === 'docker' ? rest.slice(rest.indexOf('compose') + 1) : rest; return (name === 'docker-compose' || rest.includes('compose')) && r.includes('up') && !r.some(t => t === '-d' || t === '--detach'); }
  if (name === 'tail') return rest.some(t => t === '-f' || t === '-F' || t === '--follow' || /^-[a-zA-Z]*[fF]/.test(t));
  if (name === 'tsc') return rest.some(t => t === '-w' || t === '--watch');
  if (name === 'jest' || name === 'vitest') return rest.some(t => t === '--watch' || t === '--watchAll') || (name === 'vitest' && ['watch', 'dev'].includes(first));
  return false;
}
function gitInfo(argv) { // skip git's global options; returns { sub, rest, dirs:[-C dirs], cfg:[-c values] }
  const dirs = [], cfg = []; let k = 1;
  while (k < argv.length) {
    const t = argv[k];
    if (t === '-C') { dirs.push(argv[k + 1] || ''); k += 2; continue; }
    if (t === '-c') { cfg.push(argv[k + 1] || ''); k += 2; continue; }
    if (t === '--git-dir' || t === '--work-tree' || t === '--namespace' || t === '--config-env') { if (t === '--config-env') cfg.push(argv[k + 1] || ''); dirs.push(t === '--config-env' ? '' : argv[k + 1] || ''); k += 2; continue; }
    if (/^--(git-dir|work-tree)=/.test(t)) { dirs.push(t.split('=').slice(1).join('=')); k++; continue; }
    if (/^--config-env=/.test(t)) { cfg.push(t.slice(13)); k++; continue; }
    if (t.startsWith('-')) { k++; continue; }
    return { sub: t.toLowerCase(), rest: argv.slice(k + 1), dirs, cfg };
  }
  return { sub: '', rest: [], dirs, cfg };
}
const shortHas = (t, ch) => /^-[a-zA-Z]+$/.test(t) && t.slice(1).includes(ch);
function gitFindings(argv, cmd, ctx, F) {
  const g = gitInfo(argv), r = g.rest, has = (...w) => r.some(t => w.includes(t));
  const pos = r.filter(t => !t.startsWith('-'));
  if (g.cfg.some(c => /^core\.hookspath/i.test(c))) F.push(['hook-bypass', 'gate', 'HOOK BYPASS: overriding core.hooksPath skips the pre-push check that keeps main demoable. Fix the failing check instead.']);
  if (['commit', 'push', 'merge', 'rebase', 'cherry-pick', 'am', 'revert', 'pull', 'switch', 'checkout'].includes(g.sub) &&
      (r.some(t => t.length >= 6 && '--no-verify'.startsWith(t)) || (g.sub === 'commit' && r.some(t => shortHas(t, 'n')))))
    F.push(['hook-bypass', 'gate', 'HOOK BYPASS: --no-verify skips the checks that keep main demoable. Fix what fails instead.']);
  if (g.sub === 'config' && r.some(t => /^core\.hookspath$/i.test(t)) && !has('--get', '--list', '-l')) F.push(['hook-bypass', 'gate', 'HOOK BYPASS: changing core.hooksPath disables the team git hooks.']);
  if (['push', 'commit'].includes(g.sub) && cmd.assign.some(a => /^(HK_SKIP|HUSKY|SKIP_HOOKS|SKIP)=/.test(a))) F.push(['hook-bypass', 'gate', 'HOOK BYPASS: skipping the pre-push check. Fix the failing check instead.']);
  const inState = g.dirs.some(d => STATE_RE.test(rel(d, ctx.cwd)) || STATE_RAW.test(slash(d))) || ctx.stateCwd;
  const readonly = ['log', 'show', 'diff', 'status', 'cat-file', 'rev-parse', 'ls-files', 'grep', 'blame', 'shortlog', 'describe', 'branch', 'remote', 'ls-remote', 'fetch', 'config'].includes(g.sub);
  if (inState && !readonly) F.push(['harness-state', 'deny', 'HARNESS STATE: the team board is changed only through bash .hackathon/bin/hk.sh (claim, done, log, ...), never with git directly.']);
  if (g.sub === 'push' && r.some(t => /hackathon-state/.test(t))) F.push(['harness-state', 'deny', 'HARNESS STATE: only hk.sh pushes the hackathon-state branch.']);
  let why = '';
  switch (g.sub) {
    case 'reset': if (has('--hard', '--merge', '--keep')) why = 'reset --hard throws away uncommitted work'; break;
    case 'checkout': if (has('--', '.', '-f', '--force', '--ours', '--theirs') || r.some(t => shortHas(t, 'f'))) why = 'checkout -- / . / -f discards uncommitted changes'; break;
    case 'switch': if (has('--discard-changes', '--force') || r.some(t => /^-[a-zA-Z]*[fC]/.test(t) && !t.startsWith('--'))) why = 'switch -f/-C/--discard-changes discards changes or overwrites a branch'; break;
    case 'restore': { const staged = has('--staged') || r.some(t => shortHas(t, 'S')), wt = has('--worktree') || r.some(t => shortHas(t, 'W')); if (wt || !staged) why = 'restore overwrites working-tree changes'; break; }
    case 'clean': if (has('--force') || r.some(t => shortHas(t, 'f'))) why = 'clean -f deletes untracked files for good'; break;
    case 'branch': if (r.some(t => shortHas(t, 'D')) || ((has('--delete') || r.some(t => shortHas(t, 'd'))) && (has('--force') || r.some(t => shortHas(t, 'f'))))) why = 'branch -D deletes unmerged work'; break;
    case 'stash': if (['drop', 'clear'].includes(pos[0])) why = 'stash drop/clear deletes saved work'; break;
    case 'reflog': if (['expire', 'delete'].includes(pos[0])) why = 'reflog expire/delete removes the undo history'; break;
    case 'update-ref': if (has('-d', '--delete')) why = 'update-ref -d deletes a ref'; break;
    case 'filter-branch': case 'filter-repo': why = 'history rewrite'; break;
    case 'worktree': if (pos[0] === 'remove' && (has('--force') || r.some(t => shortHas(t, 'f')))) why = 'worktree remove --force deletes uncommitted work'; break;
    case 'push': {
      const force = has('--force', '--mirror') || r.some(t => /^--force=/.test(t) || shortHas(t, 'f'));
      const lease = r.some(t => /^--force-with-lease/.test(t));
      const refs = pos.slice(1), plus = refs.some(t => /^\+./.test(t)), del = has('--delete', '--prune') || r.some(t => shortHas(t, 'd')) || refs.some(t => /^:./.test(t));
      const shared = refs.some(t => /(^|:|\/)(main|master|develop|trunk)$/.test(t.replace(/^\+/, '')));
      if (del) why = 'push --delete / :branch / --prune deletes branches on the remote';
      else if (force || (plus && !lease)) why = 'force push rewrites history your teammates have pulled';
      else if (lease && (shared || !refs.length)) why = 'force push to a shared branch';
      break;
    }
  }
  if (why) F.push(['git-destructive', 'gate', `DESTRUCTIVE GIT: ${why}. Prefer a safe route: commit or stash first, git revert instead of reset, a new branch instead of force.`]);
}
const DEL_CODE = /\b(rmtree|rmSync|rmdirSync|unlinkSync|rm_rf|remove_dir_all|os\.(remove|unlink|rmdir|removedirs)|shutil\.(rmtree|move)|fs\.(rm|rmdir|unlink)\b|fs\.promises\.(rm|rmdir|unlink)|rimraf|FileUtils\.(rm|remove)|File\.delete|Deno\.remove|\.unlink\(|truncateSync|drop\s+(table|database|schema)|truncate\s+table|delete\s+from)\b/i;
const NET_CMD = new Set(['curl', 'wget', 'fetch', 'http', 'https', 'xh', 'aria2c', 'iwr', 'invoke-webrequest', 'irm', 'invoke-restmethod']);
function interpCode(name, rest, cmd) {
  const flags = /^(python|py)/.test(name) ? ['-c'] : name === 'php' ? ['-r'] : /^(pwsh|powershell)$/.test(name) ? ['-c', '-command', '-Command', '-EncodedCommand', '-e'] : ['-e', '--eval', '-p', '--print', '-E', '-x'];
  const codes = [];
  for (let k = 0; k < rest.length; k++) {
    const t = rest[k];
    if (flags.includes(t) && rest[k + 1] !== undefined) codes.push(rest[k + 1]);
    else if (/^-[a-zA-Z]+$/.test(t) && flags.some(f => f.length === 2 && t.endsWith(f[1])) && rest[k + 1] !== undefined) codes.push(rest[k + 1]);
  }
  for (const h of cmd.heredocs) codes.push(h);
  return codes;
}
function analyse(src, ctx, depth, F) {
  if (depth > 4) return;
  const cmds = parseShell(src);
  const pipes = {};
  for (const c of cmds) (pipes[c.pipeline] = pipes[c.pipeline] || []).push(c);
  for (const cmd of cmds) {
    for (const s of cmd.subs) analyse(s, ctx, depth + 1, F);
    const netSub = cmd.procsubs.concat(cmd.subs).some(b => parseShell(b).some(c => NET_CMD.has(base(unwrap(c.argv).argv[0]))));
    const first = base(cmd.argv[0]);
    if (netSub && (first === 'eval' || first === 'source' || first === '.' || SHELLS.has(first) || INTERP.test(first) || cmd.procsubs.length))
      F.push(['remote-exec', 'gate', 'REMOTE CODE: running a script straight from the internet. Download it, read it, then run it, or ask your human.']);
    const u = unwrap(cmd.argv);
    for (const s of u.nested) analyse(s, ctx, depth + 1, F);
    if (u.wrappers.some(w => w === 'sudo' || w === 'doas')) F.push(['sudo', 'gate', 'SUDO: root access is never needed for a hackathon project; install things in user space (npm, pip --user, brew).']);
    if (u.envDump) F.push(['secrets', 'gate', 'SECRETS: printing the environment exposes API tokens. Check one variable with [ -n "$NAME" ] && echo set.']);
    const argv = u.argv; if (!argv.length) continue;
    const name = base(argv[0]), rest = argv.slice(1), nonflag = rest.filter(t => !t.startsWith('-'));
    if (name === 'su' || name === 'pkexec') F.push(['sudo', 'gate', 'SUDO: root access is never needed for a hackathon project.']);
    if (name === 'cd') { const d = rest[0] || '~'; ctx.stateCwd = STATE_RE.test(rel(d, ctx.cwd)) || STATE_RAW.test(slash(d)); continue; }
    // harness: hk.sh commands reserved for humans
    const hkAt = /hk\.sh$/.test(slash(argv[0])) ? 0 : (SHELLS.has(name) && /hk\.sh$/.test(slash(rest[0] || '')) ? 1 : -1);
    if (hkAt >= 0) {
      const a = argv.slice(hkAt + 1), sub = a[0] || '', arg = a[1] || '';
      const human = ({ init: 1, note: 1, archive: 1, discord: arg !== 'status', auto: arg === 'on' || arg === 'clear', solo: arg !== 'off', 'demo-first': ['on', 'off', 'clear'].includes(arg) })[sub];
      if (human) F.push(['human-only', 'deny', `HUMAN ONLY: "hk.sh ${sub}${arg ? ' ' + arg : ''}" changes the team's identity, modes or channels. Ask your human to run it in their own terminal.`]);
      continue;
    }
    if (name === 'printenv' && (!nonflag.length || nonflag.some(t => /key|token|secret|pass|auth|webhook/i.test(t)))) F.push(['secrets', 'gate', 'SECRETS: printing environment variables exposes API tokens.']);
    if (name === 'export' && rest.some(t => /^(HK_SKIP|HUSKY|HK_GUARD|HK_GUARD_OFF)=/.test(t))) F.push(['hook-bypass', 'gate', 'HOOK BYPASS: this turns off the team checks or the guard for the rest of the shell.']);
    if (name === 'git') gitFindings(argv, cmd, ctx, F);
    // destructive file operations
    if (name === 'rm' && rest.some(t => t === '--recursive' || /^-[a-zA-Z]*[rR]/.test(t))) {
      const targets = nonflag.length ? nonflag : ['?'];
      if (!targets.every(t => safeDelTarget(t, ctx.cwd))) F.push(['rm-recursive', 'gate', `RECURSIVE DELETE: rm -r ${targets.slice(0, 3).join(' ')} can't be undone. Delete specific files, or move them to a _to_delete/ folder.`]);
    }
    if (name === 'find' && rest.some((t, k) => t === '-delete' || (/^-(exec|execdir|ok|okdir)$/.test(t) && /^(rm|shred|unlink|rmdir)$/.test(base(rest[k + 1] || ''))))) {
      if (!safeDelTarget(nonflag[0] || '.', ctx.cwd)) F.push(['rm-recursive', 'gate', 'RECURSIVE DELETE: find -delete / -exec rm removes many files at once.']);
    }
    if ((name === 'npx' || name === 'bunx') && /^(rimraf|del-cli|trash-cli)$/.test(base(nonflag[0] || '').replace(/@[^/]*$/, '')) && !nonflag.slice(1).every(t => safeDelTarget(t, ctx.cwd))) F.push(['rm-recursive', 'gate', 'RECURSIVE DELETE via rimraf.']);
    if (name === 'dd' && rest.some(t => /^of=/i.test(t)) && !rest.some(t => /^of=\/(tmp|dev\/null)/.test(t))) F.push(['disk', 'gate', 'DISK WRITE: dd of= overwrites a file or device.']);
    if (/^(mkfs(\..*)?|wipefs|shred|fdisk|parted|diskutil|format)$/.test(name)) F.push(['disk', 'gate', `DISK: ${name} destroys data.`]);
    if (name === 'truncate' && !nonflag.every(t => safeDelTarget(t, ctx.cwd))) F.push(['disk', 'gate', 'TRUNCATE empties a file.']);
    // code run by an interpreter: deletes, secret reads, shell-outs
    if (INTERP.test(name)) {
      for (const code of interpCode(name, rest, cmd)) {
        if (DEL_CODE.test(code)) F.push(['interp-delete', 'gate', `DELETE VIA ${name.toUpperCase()}: this one-liner deletes files or data. Delete specific files with rm, or ask your human.`]);
        if (/\.env\b(?!\.example)|id_rsa|\.pem\b|\.ssh\//.test(code)) F.push(['secrets', 'gate', 'SECRETS: this code reads a credentials file.']);
        if (/subprocess|os\.system|child_process|execSync|spawnSync|exec\(|system\(|popen|Bun\.spawn|Deno\.Command|shell_exec|`/.test(code))
          for (const lit of code.match(/(["'`])((?:\\.|(?!\1).){4,}?)\1/g) || []) analyse(lit.slice(1, -1), ctx, depth + 1, F);
      }
    }
    if (SHELLS.has(name) || name === 'source' || name === '.') {
      for (const h of cmd.heredocs) analyse(h, ctx, depth + 1, F);
    }
    if (name === 'npm' && rest[0] === 'pkg' && /^(set|delete)$/.test(rest[1] || '') && rest.some(t => /^scripts\.check\b/.test(t))) F.push(['config-weaken', 'gate', 'CHECK SCRIPT: the "check" script is what keeps main demoable (pre-push). Fix the code instead of weakening it.']);
    // npx of an unknown package: typosquat risk
    let pkg = '';
    if (name === 'npx' || name === 'bunx') { const r = rest.slice(); for (let k = 0; k < r.length; k++) { if (r[k] === '-p' || r[k] === '--package') { pkg = r[k + 1] || ''; break; } if (/^--package=/.test(r[k])) { pkg = r[k].slice(10); break; } if (!r[k].startsWith('-')) { pkg = r[k]; break; } } }
    else if ((name === 'pnpm' || name === 'yarn') && rest[0] === 'dlx') pkg = rest.find((t, k) => k > 0 && !t.startsWith('-')) || '';
    else if (name === 'npm' && (rest[0] === 'exec' || rest[0] === 'x')) pkg = rest.find((t, k) => k > 0 && !t.startsWith('-')) || '';
    if (pkg) { const p = pkg.replace(/^(@[^/@]+\/[^@]+|[^@]+)@.*$/, '$1'); if (!KNOWN_NPX.has(p) && !/^(rimraf|del-cli)$/.test(p) && !/^\.{0,2}\//.test(p)) F.push(['npx-unknown', 'gate', `UNKNOWN PACKAGE: npx ${p} downloads and runs code from npm. Check the exact name on npmjs.com (typosquats are common) or ask your human.`]); }
    // files written by this command
    const writes = cmd.redirs.filter(x => x.op !== '<' && x.op !== '<<<').map(x => x.target);
    if (name === 'tee') writes.push(...nonflag);
    if (['mv', 'rm', 'rmdir', 'unlink', 'touch', 'shred', 'truncate'].includes(name)) writes.push(...nonflag);
    if (['cp', 'install', 'ln', 'rsync', 'scp'].includes(name) && nonflag.length > 1) writes.push(nonflag[nonflag.length - 1]);
    if ((name === 'chmod' || name === 'chown') && nonflag.length > 1) writes.push(...nonflag.slice(1));
    if ((name === 'sed' || name === 'perl') && rest.some(t => t === '--in-place' || /^-[a-zA-Z]*i/.test(t) || /^--in-place=/.test(t))) writes.push(...nonflag.slice(rest.some(t => t === '-e' || t === '--expression') ? 0 : 1));
    if (name === 'dd') writes.push(...rest.filter(t => /^of=/.test(t)).map(t => t.slice(3)));
    for (const w of writes) {
      const r = rel(w, ctx.cwd);
      if (STATE_RE.test(r) || STATE_RAW.test(slash(w))) F.push(['harness-state', 'deny', `HARNESS STATE: ${r || w} is written only by hk.sh (identity, modes, board). Use bash .hackathon/bin/hk.sh.`]);
      else if (HARNESS_RE.test(r)) F.push(['harness-config', 'gate', `HARNESS CONFIG: ${r} holds the team's safety settings, hooks or rules. Change it only if your human asked.`]);
      else if (LINT_RE.test(r) && fs.existsSync(path.resolve(ROOT, r))) F.push(['config-weaken', 'gate', `LINT CONFIG: fix the code instead of loosening ${r}.`]);
      else if (/(^|\/)(package\.json|tsconfig[\w.-]*\.json)$/.test(r) && ['sed', 'perl'].includes(name)) F.push(['config-weaken', 'gate', `${path.basename(r)}: edit it with the Edit tool (so the check script and strict settings stay visible), not sed.`]);
      if (isSecret(w) && !/^\.env\.(example|sample|template)$/.test(path.basename(w))) F.push(['secrets', 'gate', `SECRETS: this writes to ${path.basename(w)}. Secret values come from your human, never from the agent.`]);
    }
    // reading secrets (any argument naming a credentials file)
    const readOk = ['echo', 'printf', 'ls', 'test', '[', 'stat', 'wc', 'file', 'du', 'touch', 'mkdir', 'which'].includes(name) ||
      (name === 'git' && /^(check-ignore|ls-files|status|log|rm|mv)$/.test(gitInfo(argv).sub));
    if (!readOk) {
      const toks = rest.concat(cmd.redirs.filter(x => x.op === '<').map(x => x.target)).flatMap(t => [t, ...t.split(/[=:,]/).slice(1)]);
      const hit = toks.find(isSecret);
      if (hit) F.push(['secrets', name === 'git' && gitInfo(argv).sub === 'add' ? 'gate' : 'gate', name === 'git' && gitInfo(argv).sub === 'add'
        ? `SECRETS: git add ${path.basename(hit)} would commit credentials. Keep it in .gitignore; commit a .env.example with empty values instead.`
        : `SECRETS: this reads ${path.basename(hit)} (credentials). Don't print or copy secret values; read .env.example for the variable names, or ask your human.`]);
    }
    // a long-running server in the foreground hangs the turn
    const bgWrapped = u.wrappers.some(w => ['nohup', 'setsid', 'timeout', 'gtimeout'].includes(w)) || cmd.bg || ['tmux', 'screen', 'pm2'].includes(name);
    if (!bgWrapped && !ctx.background && devServer(name, rest)) {
      const shown = argv.join(' ').slice(0, 60);
      F.push(['dev-server', 'deny', name === 'tail'
        ? 'FOREGROUND WAIT: tail -f never exits and would hang your turn. Use tail -n 50 <file>.'
        : `FOREGROUND SERVER: "${shown}" never exits and would hang your turn. Start it in the background (Bash tool run_in_background, or: nohup ${shown} > .hackathon/dev.log 2>&1 &), then check it with curl -s localhost:<port> or tail -n 30 .hackathon/dev.log.`]);
    }
  }
  // pipelines feeding a shell or interpreter from the network or a decoder
  for (const k of Object.keys(pipes)) {
    const p = pipes[k]; if (p.length < 2) continue;
    const names = p.map(c => { const a = unwrap(c.argv).argv; return { n: base(a[0]), rest: a.slice(1) }; });
    const fromNet = names.some(x => NET_CMD.has(x.n) || (x.n === 'base64' && x.rest.some(t => /^-(d|D|-decode)$/.test(t))) || x.n === 'xxd' || (x.n === 'openssl' && x.rest.includes('enc')));
    const toShell = names.slice(1).some(x => (SHELLS.has(x.n) || INTERP.test(x.n)) && !x.rest.some(t => !t.startsWith('-') && t !== '-'));
    if (fromNet && toShell) F.push(['remote-exec', 'gate', 'REMOTE CODE: piping a download (or decoded blob) straight into a shell or interpreter. Download it, read it, then run it, or ask your human.']);
  }
}
function guardFindings(input) {
  const F = [], tool = String(input.tool_name || ''), ti = input.tool_input || {};
  const cwd = input.cwd || ROOT;
  if (tool === 'Bash' || tool === 'PowerShell') {
    analyse(String(ti.command || ''), { cwd, background: ti.run_in_background === true, stateCwd: STATE_RE.test(rel(cwd)) }, 0, F);
  } else if (/^(Edit|Write|MultiEdit|NotebookEdit|Read)$/.test(tool)) {
    const fp = ti.file_path || ti.notebook_path || ti.path || ''; const r = rel(fp, cwd), b = path.basename(slash(fp));
    if (tool === 'Read') { if (isSecret(fp)) F.push(['secrets', 'deny', `SECRETS: ${b} holds credentials. Read .env.example for variable names, or ask your human.`]); }
    else {
      const exists = fs.existsSync(path.resolve(cwd, fp));
      const text = [ti.new_string, ti.content, ti.new_source].concat((ti.edits || []).map(e => e.new_string)).filter(x => typeof x === 'string').join('\n');
      const oldText = [ti.old_string].concat((ti.edits || []).map(e => e.old_string)).filter(x => typeof x === 'string').join('\n');
      if (STATE_RE.test(r) || STATE_RAW.test(slash(fp))) F.push(['harness-state', 'deny', `HARNESS STATE: ${r} is written only by bash .hackathon/bin/hk.sh (claim, done, log, decide, ...).`]);
      else if (HARNESS_RE.test(r)) F.push(['harness-config', 'gate', `HARNESS CONFIG: ${r} holds the team's safety settings, hooks or rules. Change it only if your human asked.`]);
      if (exists && LINT_RE.test(r)) F.push(['config-weaken', 'gate', `LINT CONFIG: fix the code instead of loosening ${b}.`]);
      if (/(^|\/)tsconfig[\w.-]*\.json$/.test(r) && /"(strict|noImplicitAny|strictNullChecks)"\s*:\s*false/.test(text)) F.push(['config-weaken', 'gate', 'TSCONFIG: turning strict checks off hides real errors. Fix the types instead.']);
      if (b === 'package.json' && exists) {
        let changed = /"check"\s*:/.test(text) || /"check"\s*:/.test(oldText);
        if (tool === 'Write' && typeof ti.content === 'string') { try { changed = (JSON.parse(ti.content).scripts || {}).check !== (jread(path.resolve(cwd, fp), {}).scripts || {}).check; } catch {} }
        if (changed) F.push(['config-weaken', 'gate', 'CHECK SCRIPT: the "check" script is what keeps main demoable (pre-push). Fix the code instead of weakening it.']);
      }
      if (isSecret(fp)) F.push(['secrets', 'gate', `SECRETS: ${b} holds credentials. Secret values come from your human, never from the agent.`]);
    }
  } else if (/^mcp__/.test(tool)) {
    if (/(delete|remove|destroy|drop|purge|wipe|transfer|archive|rename|env_?var|environment_variable|set_env|update_env|secret|domain|dns|merge|force|rollback|promote|billing|member|collaborator|permission|visibility)/i.test(tool.replace(/^mcp__[^_]+__/, '')))
      F.push(['mcp-risky', 'gate', `RISKY MCP ACTION: ${tool.replace(/^mcp__/, '')} changes or deletes things outside this repo (deployments, env vars, repos, members).`]);
  }
  const offIds = String(env.HK_GUARD_OFF || '').split(/[\s,]+/).filter(Boolean);
  const seen = new Set();
  return F.filter(([id, , msg]) => !offIds.includes(id) && !seen.has(msg) && seen.add(msg));
}
function guardDecision(input) {
  if (off(env.HK_GUARD)) return null;
  const F = guardFindings(input); if (!F.length) return null;
  const unattended = autoOn() || ['bypassPermissions', 'dontAsk', 'auto'].includes(input.permission_mode);
  const decision = F.some(f => f[1] === 'deny') || unattended ? 'deny' : 'ask';
  let reason = F.map(f => f[2]).join(' ');
  if (decision === 'deny' && unattended && F.some(f => f[1] === 'gate')) reason += ' Nobody is here to approve this, so it is refused: take a safer route, or log "BLOCKED needs a human: <what>" with hk.sh and move on. Never work around the guard.';
  else if (decision === 'ask') reason += ' (hackathon guard: needs your human\'s OK)';
  return { decision, reason, ids: [...new Set(F.map(f => f[0]))] };
}
function guard(input) {
  const d = guardDecision(input); if (!d) return;
  const what = input.tool_name === 'Bash' ? String((input.tool_input || {}).command || '') : `${input.tool_name} ${((input.tool_input || {}).file_path) || ''}`;
  try { fs.mkdirSync(HH, { recursive: true }); fs.appendFileSync(path.join(HH, 'guard.log'), `${new Date().toISOString()}\t${d.decision}\t${d.ids.join(',')}\t${what.replace(/\s+/g, ' ').slice(0, 200)}\n`); } catch {}
  out({ hookSpecificOutput: { hookEventName: 'PreToolUse', permissionDecision: d.decision, permissionDecisionReason: d.reason } });
}

// ---------- monitor: edits, loops, context, budget ----------
const stFile = s => path.join(HH, s + '.json');
const loadSt = s => jread(stFile(s), {});
const saveSt = (s, o) => wr(stFile(s), JSON.stringify(o));
function ctxPct(input, s) {
  const st = jread(path.join(HH, s + '.stat'), null);
  if (st && Date.now() - st.t < 300000 && typeof st.pct === 'number') return st.pct;
  const tp = input.transcript_path; if (!tp) return null;
  try {
    const fd = fs.openSync(tp, 'r'), size = fs.fstatSync(fd).size, len = Math.min(size, 400000), buf = Buffer.alloc(len);
    fs.readSync(fd, buf, 0, len, size - len); fs.closeSync(fd);
    const lines = buf.toString('utf8').split('\n');
    for (let k = lines.length - 1; k >= (len < size ? 1 : 0); k--) {
      let rec; try { rec = JSON.parse(lines[k]); } catch { continue; }
      const u = rec && rec.message && rec.message.usage; if (!u) continue;
      const tok = (u.input_tokens || 0) + (u.cache_read_input_tokens || 0) + (u.cache_creation_input_tokens || 0); if (!tok) continue;
      let win = num(env.HK_CTX_WINDOW, 0) || (/\[1m\]|1m/i.test((rec.message && rec.message.model) || '') ? 1e6 : 200000);
      if (tok > win) win = 1e6;
      return Math.round(tok * 100 / win);
    }
  } catch {}
  return null;
}
function costTotal() { const c = jread(path.join(HH, 'cost.json'), {}); return Object.values(c).reduce((a, x) => a + (Number(x.cost) || 0), 0); }
function post(input) {
  const s = sid(input), tool = String(input.tool_name || ''), ti = input.tool_input || {}, msgs = [];
  if (/^(Edit|Write|MultiEdit|NotebookEdit)$/.test(tool)) {
    const fp = ti.file_path || ti.notebook_path; const f = path.join(HH, s + '.edits');
    if (fp && !rd(f).split('\n').includes(fp)) { try { fs.mkdirSync(HH, { recursive: true }); fs.appendFileSync(f, fp + '\n'); } catch {} }
  }
  if (input.agent_id) return;   // subagent: leave warnings to the main agent
  const st = loadSt(s);
  // loop: the same call over and over
  const LOOP = num(env.HK_LOOP, 4);
  if (LOOP > 0 && !/^(TodoWrite|TaskUpdate|TaskList|TaskGet)$/.test(tool)) {
    const t = Object.assign({}, ti); delete t.description; delete t.timeout;
    const h = sha(tool + JSON.stringify(t)); st.ring = (st.ring || []).concat(h).slice(-8);
    const n = st.ring.filter(x => x === h).length; st.warned = st.warned || {};
    if (n >= LOOP && (st.warned[h] || 0) < n && (n === LOOP || n === LOOP * 2 || n === 8)) {
      st.warned[h] = n;
      msgs.push(`LOOP WARNING: you have made this exact ${tool} call ${n} times in your last ${st.ring.length} tool calls; repeating it won't change the result. Stop and change approach: read the error, check the docs (context7 / scout), try a different fix, or log "BLOCKED <what>" with hk.sh and move to the next task.`);
    }
  }
  // context window
  const pct = ctxPct(input, s), W = num(env.HK_CTX_WARN, 55), C = num(env.HK_CTX_CRIT, 68);
  if (pct !== null && pct >= W) {
    const b = Math.floor(pct / 5);
    if (b > (st.ctxB || 0)) {
      st.ctxB = b;
      msgs.push(pct >= C
        ? `CONTEXT ${pct}% full: finish the edit you're on, run /checkpoint, then /compact now (before auto-compaction cuts you off mid-task).`
        : `CONTEXT ${pct}% full: at your next milestone (task done and committed) run /checkpoint then /compact. Don't compact mid-edit.`);
    }
  }
  // budget (machine-wide for this project, from the statusline's cost reports)
  const budget = num(env.HK_BUDGET_USD, 0);
  if (budget > 0) {
    const c = costTotal(), lvl = c >= budget ? 2 : c >= budget * 0.8 ? 1 : 0;
    if (lvl > (st.budL || 0)) {
      st.budL = lvl;
      if (lvl === 2) {
        msgs.push(`BUDGET: $${c.toFixed(2)} spent of $${budget}. Wrap up: commit what works, /handoff, and stop.`);
        if (autoOn()) { wr(path.join(H, '.auto'), 'off\n'); spawnHk(['log', `STUCK budget: $${c.toFixed(2)} of $${budget} spent; autonomous off for @${ME() || 'me'}`]); msgs.push('Autonomous mode is now OFF on this machine (budget).'); }
      } else msgs.push(`BUDGET: $${c.toFixed(2)} of $${budget} spent (80%). Prefer cheap moves: scout for lookups, no re-reads, /compact at milestones.`);
    }
  }
  saveSt(s, st);
  if (msgs.length) out({ hookSpecificOutput: { hookEventName: 'PostToolUse', additionalContext: msgs.join('\n') } });
}
function spawnHk(args) {
  try { const p = cp.spawn('bash', [path.join(H, 'bin', 'hk.sh'), ...args], { cwd: ROOT, detached: true, stdio: 'ignore', windowsHide: true }); p.on('error', () => {}); p.unref(); } catch {}
}

// ---------- stop: check edited files, handoff, notify ----------
function findUp(dir, name) {
  let d = dir; const stop = path.dirname(ROOT);
  while (d && d !== stop && d !== path.dirname(d)) { if (fs.existsSync(path.join(d, name))) return d; d = path.dirname(d); }
  return null;
}
function pyCmd() { for (const c of ['python3', 'python']) { const r = run(c, ['-c', 'import sys'], { timeout: 4000 }); if (r.code === 0) return c; } return null; }
function checkEdited(files) {
  const errs = [], budget = num(env.HK_STOP_CHECK_TIMEOUT, 90) * 1000, t0 = Date.now();
  const left = () => Math.max(5000, budget - (Date.now() - t0));
  const ts = {}, py = [], js = [], json = [];
  for (const f of files) {
    const e = path.extname(f).toLowerCase();
    if (['.ts', '.tsx', '.mts', '.cts'].includes(e)) { const d = findUp(path.dirname(f), 'tsconfig.json'); if (d) (ts[d] = ts[d] || []).push(f); }
    else if (e === '.py') py.push(f);
    else if (['.js', '.mjs', '.cjs'].includes(e)) js.push(f);
    else if (e === '.json' && !/tsconfig|jsconfig|\.vscode/.test(f)) json.push(f);
  }
  for (const f of json) { try { JSON.parse(fs.readFileSync(f, 'utf8')); } catch (e) { errs.push(`${rel(f)}: invalid JSON: ${String(e.message).slice(0, 120)}`); } }
  for (const f of js) { const r = run(process.execPath, ['--check', f], { timeout: 8000 }); if (r.code) errs.push(...r.out.split('\n').filter(l => /SyntaxError|^\S.*:\d+$/.test(l)).slice(0, 3).map(l => `${rel(f)}: ${l.trim()}`)); }
  if (py.length) { const p = pyCmd(); if (p) for (const f of py) { const r = run(p, ['-m', 'py_compile', f], { timeout: 8000 }); if (r.code) errs.push(...r.out.trim().split('\n').slice(-3).map(l => `${rel(f)}: ${l.trim()}`)); } }
  for (const d of Object.keys(ts)) {
    if (!fs.existsSync(path.join(d, 'node_modules', 'typescript')) && !fs.existsSync(path.join(ROOT, 'node_modules', 'typescript'))) continue;
    const r = run('npx', ['--no-install', 'tsc', '--noEmit', '-p', d], { cwd: d, timeout: left() });
    if (r.err || r.code === 0 || r.code === null) continue;
    const mine = new Set(ts[d].map(f => path.resolve(f)));
    let keep = false;
    for (const l of r.out.split('\n')) {
      const m = l.match(/^(.+?)\((\d+),(\d+)\): error/) || l.match(/^(.+?):(\d+):(\d+) - error/);
      if (m) keep = mine.has(path.resolve(d, m[1]));
      if (keep && l.trim()) errs.push(m ? `${rel(path.resolve(d, m[1]))}:${m[2]} ${l.replace(/^.*?error /, 'error ').trim()}` : '    ' + l.trim());
    }
  }
  return errs;
}
function snapshot(reason) {
  const me = ME() || 'me', L = [];
  const mine = [];
  for (const l of rd(path.join(WT, 'BOARD.md')).split('\n')) { const p = l.split('|').map(x => x.trim()); if (p.length > 5 && p[2] === '@' + me && p[3] !== 'done' && p[1] !== 'id') mine.push(`${p[1]} (${p[3]}) ${p[p.length - 2] || ''}`.trim()); }
  if (mine.length) L.push(`- Your tasks: ${mine.join('; ')}`);
  const dirty = git('status', '--porcelain').split('\n').filter(Boolean).map(l => l.slice(3));
  if (dirty.length) L.push(`- Uncommitted: ${dirty.slice(0, 8).join(', ')}${dirty.length > 8 ? ` (+${dirty.length - 8} more)` : ''}`);
  const log = git('log', '-4', '--format=%h %s'); if (log) L.push(`- Recent commits: ${log.split('\n').join(' | ')}`);
  const note = rd(path.join(H, 'notes', me + '.md')).trim().split('\n').slice(0, 8).join('\n  ');
  if (note) L.push(`- Your /checkpoint note:\n  ${note}`);
  if (!L.length) return '';
  const t = new Date(); const hm = `${String(t.getHours()).padStart(2, '0')}:${String(t.getMinutes()).padStart(2, '0')}`;
  const s = `HANDOFF for @${me} (saved ${hm}${reason ? ', ' + reason : ''}): pick up from here.\n${L.join('\n')}\n`;
  wr(path.join(HH, `handoff-${me}.md`), s); return s;
}
function notify(title, msg) {
  if (off(env.HK_NOTIFY)) return;
  try {
    let c, a;
    if (env.HK_NOTIFY_CMD) { c = env.HK_NOTIFY_CMD; a = [title, msg]; if (/\.sh$/.test(c)) { a = [c, title, msg]; c = 'bash'; } }
    else if (process.platform === 'darwin') { c = 'osascript'; a = ['-e', `display notification ${JSON.stringify(msg)} with title ${JSON.stringify(title)}`]; }
    else if (process.platform === 'win32' || /microsoft/i.test(rd('/proc/version'))) {
      const q = x => String(x).replace(/'/g, "''");
      c = 'powershell.exe'; a = ['-NoProfile', '-Command', `[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null; $t = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02); $x = $t.GetElementsByTagName('text'); $x.Item(0).AppendChild($t.CreateTextNode('${q(title)}')) > $null; $x.Item(1).AppendChild($t.CreateTextNode('${q(msg)}')) > $null; [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\\WindowsPowerShell\\v1.0\\powershell.exe').Show([Windows.UI.Notifications.ToastNotification]::new($t))`];
    } else { if (!env.DISPLAY && !env.WAYLAND_DISPLAY) return; c = 'notify-send'; a = [title, msg]; }
    const p = cp.spawn(c, a, { detached: true, stdio: 'ignore', windowsHide: true }); p.on('error', () => {}); p.unref();
  } catch {}
}
function stop(input) {
  const s = sid(input), st = loadSt(s), ef = path.join(HH, s + '.edits');
  if (!input.agent_id && !off(env.HK_STOP_CHECK)) {
    const files = [...new Set(rd(ef).split('\n').filter(Boolean))].map(f => path.resolve(input.cwd || ROOT, f)).filter(f => fs.existsSync(f));
    const errs = files.length ? checkEdited(files) : [];
    if (errs.length) {
      const fp = sha(errs.join('\n'));
      const tries = st.stopFp === fp ? (st.stopTries || 0) + 1 : 1;
      if (tries <= num(env.HK_STOP_TRIES, 2)) {
        st.stopFp = fp; st.stopTries = tries; saveSt(s, st);
        return out({ decision: 'block', reason: `STOP CHECK: files you edited this turn have errors. Fix them with minimal changes (don't loosen configs or delete code), then finish:\n${errs.slice(0, 25).join('\n')}${errs.length > 25 ? `\n(+${errs.length - 25} more lines)` : ''}` });
      }
      st.stopFp = null; st.stopTries = 0; saveSt(s, st); wr(ef, '');
      snapshot('turn end');
      return out({ systemMessage: `Stop check: errors remain in edited files after ${tries - 1} fix attempts (${errs.length} lines). First: ${errs[0]}` });
    }
    if (files.length) wr(ef, '');
    if (st.stopFp) { st.stopFp = null; st.stopTries = 0; saveSt(s, st); }
  }
  if (input.agent_id) return;
  snapshot('turn end');
  const t0 = num(rd(path.join(HH, s + '.turn')).trim(), 0), secs = t0 ? Math.round((Date.now() - t0) / 1000) : 0;
  if (t0 && secs >= num(env.HK_NOTIFY_MIN, 45)) {
    wr(path.join(HH, s + '.turn'), '');
    const me = ME(), m = Math.floor(secs / 60);
    notify(`Claude${me ? ' @' + me : ''} is done`, `Finished after ${m ? m + 'm ' : ''}${secs % 60}s${autoOn() ? ' (autonomous)' : ''}. ${path.basename(ROOT)}`);
  }
}
function prompt(input) { wr(path.join(HH, sid(input) + '.turn'), String(Date.now())); }
function precompact(input) { snapshot('before ' + (input.trigger || 'auto') + ' compaction'); }
function start(input) {
  const src = input.source || 'startup', me = ME() || 'me';
  // housekeeping: drop per-session files older than 3 days
  try { for (const f of fs.readdirSync(HH)) { const p = path.join(HH, f); if (/^[\w-]+\.(json|edits|turn|stat)$/.test(f) && Date.now() - fs.statSync(p).mtimeMs > 3 * 864e5) fs.unlinkSync(p); } } catch {}
  const hf = path.join(HH, `handoff-${me}.md`); let age = Infinity; try { age = Date.now() - fs.statSync(hf).mtimeMs; } catch {}
  if (['compact', 'resume', 'clear'].includes(src) && age < 864e5) { const s = rd(hf).trim(); if (s) process.stdout.write(s + '\n'); }
  else if (src === 'startup' && age < 12 * 36e5) { const s = rd(hf).trim(); if (s) process.stdout.write(s.replace(/^HANDOFF/, 'LAST SESSION') + '\n'); }
}

// ---------- statusline ----------
function statusline(input) {
  const s = sid(input), parts = [], me = ME();
  const m = minsLeft();
  if (m !== null) parts.push(m <= 0 ? '\x1b[31m⏱ deadline passed\x1b[0m' : (m <= 60 ? '\x1b[31m' : m <= 240 ? '\x1b[33m' : '') + `⏱ ${Math.floor(m / 60)}h${String(m % 60).padStart(2, '0')}m` + (m <= 240 ? '\x1b[0m' : ''));
  if (me) {
    const mine = [];
    for (const l of rd(path.join(WT, 'BOARD.md')).split('\n')) { const p = l.split('|').map(x => x.trim()); if (p.length > 4 && p[2] === '@' + me && p[3] === 'doing') mine.push(p[1]); }
    parts.push(`@${me}${mine.length ? ' ' + mine.slice(0, 2).join(',') : ''}`);
  }
  const t = modeTable(), flags = [];
  if (t.solo && t.solo !== '-') flags.push('SOLO ' + t.solo);
  if (autoOn()) flags.push('AUTO');
  if (demoFirstOff()) flags.push('FULL-BUILD');
  if (flags.length) parts.push(flags.join(' '));
  const demo = rd(path.join(WT, 'LOG.md')).split('\n').filter(l => / DEMO (GREEN|RED)/.test(l)).pop();
  if (demo) parts.push(/ DEMO GREEN/.test(demo) ? 'demo 🟢' : 'demo 🔴');
  const cw = input.context_window || {}, pct = typeof cw.used_percentage === 'number' ? Math.round(cw.used_percentage) : null;
  if (pct !== null) parts.push((pct >= num(env.HK_CTX_CRIT, 68) ? '\x1b[31m' : pct >= num(env.HK_CTX_WARN, 55) ? '\x1b[33m' : '') + `ctx ${pct}%` + (pct >= num(env.HK_CTX_WARN, 55) ? '\x1b[0m' : ''));
  const cost = input.cost && Number(input.cost.total_cost_usd);
  if (Number.isFinite(cost)) {
    const c = jread(path.join(HH, 'cost.json'), {}); c[s] = { cost, t: Date.now() }; wr(path.join(HH, 'cost.json'), JSON.stringify(c));
    const tot = costTotal(); wr(path.join(HH, 'cost-total'), tot.toFixed(2));
    const b = num(env.HK_BUDGET_USD, 0);
    parts.push(`$${cost.toFixed(2)}${tot > cost + 0.005 ? ` (all $${tot.toFixed(2)})` : ''}${b ? `/$${b}` : ''}`);
  }
  if (pct !== null || Number.isFinite(cost)) wr(path.join(HH, s + '.stat'), JSON.stringify({ pct, cost, t: Date.now() }));
  process.stdout.write(parts.join(' │ ') + '\n');
}

// ---------- scan: deterministic pre-submission security checks ----------
const KEY_RES = [
  ['AWS key', /\b(AKIA|ASIA)[A-Z0-9]{16}\b/], ['GitHub token', /\b(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}/],
  ['Anthropic/OpenAI key', /\bsk-(ant-)?[A-Za-z0-9_-]{24,}/], ['Stripe live key', /\b[sr]k_live_[A-Za-z0-9]{16,}/],
  ['Slack token', /\bxox[baprs]-[A-Za-z0-9-]{10,}/], ['Google API key', /\bAIza[0-9A-Za-z_-]{35}\b/],
  ['private key', /-----BEGIN [A-Z ]*PRIVATE KEY-----/], ['Discord webhook', /discord(app)?\.com\/api\/webhooks\/\d+\/[\w-]{20,}/],
  ['hardcoded secret', /\b(api[_-]?key|secret|token|password|passwd)\b["']?\s*[:=]\s*["'][^"'\s$<{]{16,}["']/i],
];
const HIDDEN = /[\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u2069\uFEFF]/;
function scan() {
  const res = [], add = (lvl, msg) => res.push(`${lvl.padEnd(4)} ${msg}`);
  const files = git('ls-files').split('\n').filter(Boolean);
  const sec = files.filter(f => isSecret(f));
  sec.length ? add('FAIL', `secret files are committed: ${sec.slice(0, 5).join(', ')} -> git rm --cached <file>, add to .gitignore, rotate the keys`) : add('PASS', 'no credentials files tracked');
  let hits = 0;
  for (const f of files) {
    if (/(^|\/)(node_modules|dist|build|\.next|vendor)\/|\.(png|jpe?g|gif|webp|ico|pdf|zip|gz|woff2?|ttf|mp4|mp3|lock)$|(package-lock|pnpm-lock|yarn)\.ya?ml|package-lock\.json|\.env\.example$/.test(f)) continue;
    let txt; try { const st = fs.statSync(path.join(ROOT, f)); if (st.size > 1e6) continue; txt = fs.readFileSync(path.join(ROOT, f), 'utf8'); } catch { continue; }
    if (txt.includes('\u0000')) continue;
    const lines = txt.split('\n');
    for (let k = 0; k < lines.length && hits < 15; k++) {
      for (const [n, re] of KEY_RES) if (re.test(lines[k]) && !/process\.env|os\.environ|import\.meta\.env|example|placeholder|your[_-]|xxxx|<.*>/i.test(lines[k])) { add('FAIL', `${n} in ${f}:${k + 1} -> move it to .env (gitignored) and rotate it`); hits++; break; }
      if (/^(CLAUDE|AGENTS|README)\.md$|^\.claude\/|^\.hackathon\/rules\/|\.mcp\.json$/.test(f) && HIDDEN.test(lines[k])) { add('FAIL', `hidden unicode (zero-width/bidi) in ${f}:${k + 1}: possible prompt injection; inspect it`); hits++; }
    }
  }
  if (!hits) add('PASS', 'no keys, tokens or hidden unicode found in tracked files');
  const ig = run('git', ['-C', ROOT, 'check-ignore', '-q', '.env']);
  ig.code === 0 ? add('PASS', '.env is gitignored') : add('WARN', '.env is NOT gitignored: add .env* (and keep .env.example) to .gitignore');
  const hp = git('config', 'core.hooksPath'); hp === '.githooks' ? add('PASS', 'team git hooks active (core.hooksPath=.githooks)') : add('WARN', `core.hooksPath is '${hp || 'unset'}': pre-push check and contract alerts are off (hk.sh init sets it)`);
  const set = jread(path.join(ROOT, '.claude', 'settings.json'), {}), hooksTxt = JSON.stringify(set.hooks || {});
  /hh\.js[^,}]*guard/.test(hooksTxt) ? add('PASS', 'guard hook wired in .claude/settings.json') : add('FAIL', 'guard hook missing from .claude/settings.json');
  ((set.permissions || {}).deny || []).some(d => /\.env/.test(d)) ? add('PASS', 'deny rules for .env present') : add('WARN', 'no .env deny rules in .claude/settings.json');
  if (off(env.HK_GUARD)) add('WARN', 'HK_GUARD=off: the guard is disabled');
  const remote = git('remote').split('\n')[0];
  if (remote && files.length) {
    const r = run('git', ['-C', ROOT, 'ls-remote', '--heads', remote, 'hackathon-state'], { timeout: 10000 });
    if (r.code === 0 && /hackathon-state/.test(r.out)) add('WARN', `the team board branch (hackathon-state) is on '${remote}': if the repo is public, judges can read your LOG. After submitting, a human runs: bash .hackathon/bin/hk.sh archive --delete-remote`);
  }
  const gl = rd(path.join(HH, 'guard.log')).split('\n').filter(Boolean).filter(l => Date.now() - Date.parse(l.split('\t')[0]) < 864e5);
  if (gl.length) { const den = gl.filter(l => l.split('\t')[1] === 'deny').length; add('INFO', `guard: ${gl.length} blocked/asked in 24h (${den} refused); latest: ${gl.slice(-3).map(l => l.split('\t')[2] + ': ' + l.split('\t')[3].slice(0, 50)).join(' | ')}`); }
  const fails = res.filter(l => l.startsWith('FAIL')).length;
  process.stdout.write(`SECURITY SCAN: ${fails ? fails + ' FAIL' : 'no failures'}\n${res.join('\n')}\n`);
}

// ---------- entry ----------
const cmd = process.argv[2] || '';
try {
  switch (cmd) {
    case 'guard': guard(stdin()); break;
    case 'post': post(stdin()); break;
    case 'stop': stop(stdin()); break;
    case 'prompt': prompt(stdin()); break;
    case 'precompact': precompact(stdin()); break;
    case 'start': start(stdin()); break;
    case 'statusline': statusline(stdin()); break;
    case 'scan': scan(); break;
    case 'snapshot': process.stdout.write(snapshot(process.argv[3] || 'manual') || 'nothing to hand off\n'); break;
    case 'check': {
      const c = process.argv[3] || ''; if (process.argv.includes('--auto')) env.HK_TEST_AUTO = '1';
      const d = guardDecision({ tool_name: 'Bash', tool_input: { command: c }, cwd: process.cwd() });
      process.stdout.write(d ? `${d.decision}\t${d.ids.join(',')}\t${d.reason}\n` : 'allow\n'); break;
    }
    default: process.stdout.write('usage: hh.js guard|post|stop|prompt|precompact|start|statusline|scan|snapshot|check "<cmd>"\n'); process.exitCode = 1;
  }
} catch (e) {
  // a hook must never take the session down; the guard fails closed for Bash only when it can't parse at all
  if (cmd === 'guard' && !off(env.HK_GUARD)) out({ hookSpecificOutput: { hookEventName: 'PreToolUse', permissionDecision: 'ask', permissionDecisionReason: `hackathon guard error (${String(e && e.message).slice(0, 80)}): needs your human's OK` } });
}
