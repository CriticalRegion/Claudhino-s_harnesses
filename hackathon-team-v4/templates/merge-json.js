// Deep-merge a harness template into a project JSON file; your values win for scalars, lists are unioned.
// usage: node merge-json.js <target.json> <template.json|-> [model=x] [ponytail=on|off] [only=a,b] [strip-v3] [lean=on|off]
const fs = require('fs');
const [target, tpl, ...opts] = process.argv.slice(2);
const opt = Object.fromEntries(opts.map(o => o.includes('=') ? o.split(/=(.*)/s).slice(0, 2) : [o, true]));
const read = f => fs.existsSync(f) && fs.readFileSync(f, 'utf8').trim() ? JSON.parse(fs.readFileSync(f, 'utf8')) : {};
const isObj = v => v && typeof v === 'object' && !Array.isArray(v);
function merge(a, b) {
  if (Array.isArray(a) && Array.isArray(b)) { const s = new Set(a.map(x => JSON.stringify(x))); return a.concat(b.filter(x => !s.has(JSON.stringify(x)))); }
  if (isObj(a) && isObj(b)) { const o = { ...a }; for (const k of Object.keys(b)) o[k] = k in a ? merge(a[k], b[k]) : b[k]; return o; }
  return a;
}
let mine = read(target);
if (tpl !== '-') {
  let t = read(tpl);
  if (opt.only && t.mcpServers) t.mcpServers = Object.fromEntries(Object.entries(t.mcpServers).filter(([k]) => opt.only.split(',').includes(k)));
  mine = merge(mine, t);
}
if (opt.model) mine.model = opt.model;
if (opt.ponytail) {
  mine.enabledPlugins = mine.enabledPlugins || {};
  if (opt.ponytail === 'on') {
    mine.extraKnownMarketplaces = mine.extraKnownMarketplaces || {};
    mine.extraKnownMarketplaces.ponytail = mine.extraKnownMarketplaces.ponytail || { source: { source: 'github', repo: 'DietrichGebert/ponytail', ref: 'v5.3.3' } };
    mine.enabledPlugins['ponytail@ponytail'] = true;
  } else mine.enabledPlugins['ponytail@ponytail'] = false;
}
if (opt.lean) {   // build-stage token savings; on: add where unset (your own values win), off: remove only our values
  const LEAN = { bashOutputMaxChars: 10000, effortLevel: 'high' };
  const LEAN_ENV = { MAX_MCP_OUTPUT_TOKENS: '8000', CLAUDE_CODE_SUBAGENT_MODEL: 'haiku' };
  if (opt.lean === 'on') {
    for (const [k, v] of Object.entries(LEAN)) if (!(k in mine)) mine[k] = v;
    mine.env = isObj(mine.env) ? mine.env : {};
    for (const [k, v] of Object.entries(LEAN_ENV)) if (!(k in mine.env)) mine.env[k] = v;
  } else {
    for (const [k, v] of Object.entries(LEAN)) if (mine[k] === v) delete mine[k];
    if (isObj(mine.env)) { for (const [k, v] of Object.entries(LEAN_ENV)) if (mine.env[k] === v) delete mine.env[k];
      if (!Object.keys(mine.env).length) delete mine.env; }
  }
}
if (opt['strip-v3']) {   // remove v3's copied hooks and hk.sh permission entries
  const v3 = s => typeof s === 'string' && /hk\.sh|clock\.sh/.test(s);
  if (isObj(mine.hooks)) for (const ev of Object.keys(mine.hooks)) {
    mine.hooks[ev] = mine.hooks[ev].map(g => ({ ...g, hooks: (g.hooks || []).filter(h => !v3(h.command)) })).filter(g => g.hooks.length);
    if (!mine.hooks[ev].length) delete mine.hooks[ev];
  }
  if (isObj(mine.permissions)) for (const k of ['allow', 'ask', 'deny']) if (Array.isArray(mine.permissions[k])) mine.permissions[k] = mine.permissions[k].filter(x => !v3(x));
}
fs.writeFileSync(target, JSON.stringify(mine, null, 2) + '\n');
