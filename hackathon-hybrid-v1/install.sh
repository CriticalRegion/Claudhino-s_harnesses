#!/usr/bin/env bash
# Install the hackathon hybrid harness into a project without clobbering anything.
#   bash install.sh <your-repo> [--force]
# - Harness scripts/commands/agents: copied if missing; if yours differ they're skipped
#   (reported) unless --force.
# - PLAN.md / deadline: copied only if missing (never overwritten).
# - .gitignore: missing lines appended.  CLAUDE.md: harness section appended once.
# - .mcp.json / .claude/settings.json: deep-merged (your values win; lists are unioned;
#   --force lets harness values win). Needs node.
# README.md, GUIDE.md, tests/ and this script are not copied.
set -eu
SRC=$(cd "$(dirname "$0")" && pwd)
DST=${1:-}; FORCE=0; [ "${2:-}" = --force ] && FORCE=1
[ -n "$DST" ] && [ -d "$DST" ] || { echo "usage: bash install.sh <your-repo> [--force]"; exit 1; }
DST=$(cd "$DST" && pwd)
[ "$DST" != "$SRC" ] || { echo "install.sh: target is the harness folder itself"; exit 1; }
added=(); kept=(); merged=()

put() { tr -d '\r' < "$SRC/$1" > "$DST/$1"; }   # LF only: CRLF breaks bash (zip downloads / autocrlf on Windows)
owned() { # path: harness-owned file
  local p=$1 tmp
  mkdir -p "$DST/$(dirname "$p")"
  tmp=$(mktemp); tr -d '\r' < "$SRC/$p" > "$tmp"
  if [ ! -e "$DST/$p" ]; then put "$p"; added+=("$p")
  elif cmp -s "$tmp" "$DST/$p"; then :
  elif [ $FORCE = 1 ]; then put "$p"; merged+=("$p (overwritten)")
  else kept+=("$p (yours differs; --force to replace)"); fi
  rm -f "$tmp"
}
once() { local p=$1; mkdir -p "$DST/$(dirname "$p")"
  if [ -e "$DST/$p" ]; then kept+=("$p (kept yours)"); else put "$p"; added+=("$p"); fi; }

for p in .claude/hooks/clock.sh .claude/hooks/hh.js .githooks/pre-push .githooks/post-commit .hackathon/bin/hk.sh \
         $(cd "$SRC" && ls .claude/agents/*.md .claude/commands/*.md .hackathon/rules/*.md); do owned "$p"; done
chmod +x "$DST/.claude/hooks/clock.sh" "$DST/.claude/hooks/hh.js" "$DST/.githooks/pre-push" "$DST/.githooks/post-commit" "$DST/.hackathon/bin/hk.sh" 2>/dev/null || true
once .hackathon/PLAN.md
once .hackathon/deadline

# .gitignore / .gitattributes: append missing lines
lines() { local f=$1 n=0 line
  if [ -e "$DST/$f" ]; then
    [ -z "$(tail -c1 "$DST/$f")" ] || echo >> "$DST/$f"
    while IFS= read -r line; do line=${line%$'\r'}
      [ -n "$line" ] || continue
      grep -qxF -- "$line" "$DST/$f" || { echo "$line" >> "$DST/$f"; n=$((n+1)); }
    done < "$SRC/$f"
    [ $n -gt 0 ] && merged+=("$f (+$n lines)")
  else put "$f"; added+=("$f"); fi
  return 0; }
lines .gitignore
lines .gitattributes

# CLAUDE.md: append the harness section once
if [ ! -e "$DST/CLAUDE.md" ]; then cp "$SRC/CLAUDE.md" "$DST/CLAUDE.md"; added+=(CLAUDE.md)
elif grep -qx '# Hackathon mode' "$DST/CLAUDE.md"; then
  cmp -s "$SRC/CLAUDE.md" "$DST/CLAUDE.md" || kept+=("CLAUDE.md (has a Hackathon section; update it by hand if needed)")
else printf '\n' >> "$DST/CLAUDE.md"; cat "$SRC/CLAUDE.md" >> "$DST/CLAUDE.md"; merged+=("CLAUDE.md (section appended)"); fi

# JSON files: deep merge with node
json() { local p=$1; mkdir -p "$DST/$(dirname "$p")"
  if [ ! -e "$DST/$p" ]; then cp "$SRC/$p" "$DST/$p"; added+=("$p"); return; fi
  command -v node >/dev/null || { kept+=("$p (node not found; merge by hand)"); return; }
  if node - "$DST/$p" "$SRC/$p" "$FORCE" <<'JS'
const fs = require('fs'); const [dst, src, force] = process.argv.slice(2);
const mine = JSON.parse(fs.readFileSync(dst, 'utf8')), theirs = JSON.parse(fs.readFileSync(src, 'utf8'));
const isObj = v => v && typeof v === 'object' && !Array.isArray(v);
function merge(a, b) {
  if (Array.isArray(a) && Array.isArray(b)) {
    const seen = new Set(a.map(x => JSON.stringify(x)));
    return a.concat(b.filter(x => !seen.has(JSON.stringify(x))));
  }
  if (isObj(a) && isObj(b)) { const o = { ...a }; for (const k of Object.keys(b)) o[k] = k in a ? merge(a[k], b[k]) : b[k]; return o; }
  return force === '1' ? b : a;
}
const out = JSON.stringify(merge(mine, theirs), null, 2) + '\n';
if (out === fs.readFileSync(dst, 'utf8')) process.exit(3);
fs.writeFileSync(dst, out);
JS
  then merged+=("$p (merged)"); else [ $? = 3 ] || kept+=("$p (not valid JSON; merge by hand)"); fi; }
json .mcp.json
json .claude/settings.json

echo "Installed hackathon harness into $DST"
[ ${#added[@]} -gt 0 ]  && printf '  added:   %s\n' "${added[@]}"
[ ${#merged[@]} -gt 0 ] && printf '  merged:  %s\n' "${merged[@]}"
[ ${#kept[@]} -gt 0 ]   && printf '  skipped: %s\n' "${kept[@]}"
cat <<EOF
Next:
  1. echo "2026-11-23T14:00" > .hackathon/deadline   (your deadline, local time)  - or let /kickoff do it
  2. git add -A && git commit -m "hackathon harness" && git push
  3. Team: each person runs   bash .hackathon/bin/hk.sh init <name>
  4. claude   -> accept the project plugin prompt, then /mcp to sign in to github + vercel
EOF
