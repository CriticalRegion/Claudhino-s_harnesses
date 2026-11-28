// Total token usage in Claude Code's transcripts (all sessions and their subagents under one project folder).
// usage: node usage-sum.js <dir> [until]      until = UTC YYYY-MM-DDTHH:MM:SS: records stamped after it are left out
// prints "<output tokens> <input tokens incl. cache>"; the same numbers hk's awk fallback (USAGE_AWK) gives.
// A message appears in the log once per streamed update with the same id: the last record up to `until` counts, across all files.
const fs = require('fs'), path = require('path');
const [dir, until = ''] = process.argv.slice(2);
const files = [];
(function walk(d) {
  let es; try { es = fs.readdirSync(d, { withFileTypes: true }); } catch { return; }
  for (const e of es) { const p = path.join(d, e.name); if (e.isDirectory()) walk(p); else if (e.name.endsWith('.jsonl')) files.push(p); }
})(dir);
files.sort();   // a stable order, so "the last record wins" is the same on every run
const RE_TS = /"timestamp":"([^"]{19})/, RE_ID = /"id":"(msg_[^"]*)"/;
const RE = [/"input_tokens":(\d+)/, /"cache_creation_input_tokens":(\d+)/, /"cache_read_input_tokens":(\d+)/, /"output_tokens":(\d+)/];
const seen = new Map();   // id (or file:line when a record has none) -> [input, cache write, cache read, output]
const CHUNK = 1 << 24;
for (const f of files) {
  let fd; try { fd = fs.openSync(f, 'r'); } catch { continue; }
  const buf = Buffer.allocUnsafe(CHUNK); let carry = '', n = 0, ln = 0;
  const line = s => {
    ln++;
    if (!s.includes('"usage"')) return;
    if (until) { const t = RE_TS.exec(s); if (t && t[1] > until) return; }
    const m = RE_ID.exec(s), id = m ? m[1] : f + ':' + ln;
    const v = RE.map(r => { const x = r.exec(s); return x ? +x[1] : 0; });
    seen.set(id, v);
  };
  try {
    while ((n = fs.readSync(fd, buf, 0, CHUNK, null)) > 0) {
      const parts = (carry + buf.toString('latin1', 0, n)).split('\n');   // latin1: one byte per char, so a split multibyte character can't be damaged; every pattern here is ASCII
      carry = parts.pop();
      for (const s of parts) line(s);
    }
    if (carry) line(carry);
  } catch {} finally { fs.closeSync(fd); }
}
let o = 0, i = 0;
for (const [a, b, c, d] of seen.values()) { i += a + b + c; o += d; }
process.stdout.write(o + ' ' + i + '\n');
