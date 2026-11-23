#!/usr/bin/env bash
# hk.sh - git-backed coordination and event notifications for a hackathon team.
# Board/log/decisions live on their own branch (hackathon-state), checked out at
# .hackathon/state. Coordination never commits, pushes, pulls or rebases your code.
#
#   init <name>                      set your handle, attach (or create) the shared state branch
#   sync [--hook]                    refresh, push anything pending, print news + open tasks
#   claim <id> [--take]              take a task (--take: only when its owner is STALE)
#   release <id>                     give a task back
#   done <id> [path:line]            mark your task done and log it
#   add <id> [ref] [--after a,b]     add a task; --after = tasks it depends on
#   log "<EVENT text>"               BLOCKED / ASK @x: / ANSWER @x: / UNBLOCKS @x: / CLAIM-FILE <path>
#   note "@name text"                a human's note to someone's agent (urgent for @name)
#   decide "<text>"                  one line to DECISIONS.md
#   demo green|red "<details>"       demo-path health after a deploy
#   board                            print the board
#   discord <webhook-url> [--global] | off [--global] | test | status
#                                    post your events to Discord; a forum channel gets one post per
#                                    project, created automatically (URL stays local, never committed)
#   auto on [2h] [--me] | off [--me] | clear --me | status
#                                    autonomous mode: agents approve their own prompts (deny list still
#                                    applies), never wait for a human, keep going until work runs out
#   solo @name [2h] | off            one agent finishes alone (autonomous); everyone else is muted
# Hooks: peek, posttool, pretool, watch (exit 2 = wake the agent), permit, autostop, contract,
#        _beat, _bgfetch, _mergeboard
#
# Exit codes: 0 ok, 1 refused/failed (nothing changed remotely), 2 saved locally but NOT pushed.
set -u
# Git exports these to hooks (post-commit, pre-push); they would point our git calls at the wrong index/repo.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
ROOT=$(cd "$(dirname "$0")/../.." && pwd -P) || exit 1
ROOTL=$(cd "$(dirname "$0")/../.." && pwd)
H=$ROOT/.hackathon; WT=$H/state; BR=hackathon-state; LOCK=$H/.lock; CLOCK=$ROOT/.claude/hooks/clock.sh
SELF=$H/bin/hk.sh
ME=$(cat "$H/.me" 2>/dev/null || true); ME=${ME:-${HK_ME:-}}
STALE_MIN=${HK_STALE_MIN:-45}; WAKE_CAP=${HK_WAKE_CAP:-6}
export GIT_TERMINAL_PROMPT=0 HK_SKIP=1
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o ConnectTimeout=8}"
CMD=${1:-}; [ $# -gt 0 ] && shift

quiet_cmd(){ case $CMD in peek|posttool|pretool|watch|permit|autostop|contract|_beat|_bgfetch|_post) return 0;; esac
  [ "$CMD" = sync ] && [ "${1:-}" = --hook ]; }
die(){ echo "$*"; exit 1; }
gm(){ git -C "$ROOT" "$@"; }
g(){ git -C "$WT" "$@"; }
if ! gm rev-parse --git-dir >/dev/null 2>&1; then quiet_cmd "$@" && exit 0; die "hk: $ROOT is not a git repo"; fi

R=$(gm config hk.remote 2>/dev/null || true)
if [ -z "$R" ]; then if gm remote | grep -qx origin; then R=origin; else R=$(gm remote | head -n1); fi; fi
RREF=refs/remotes/$R/$BR

TMO=
tmo(){ local s=$1; shift
  if [ -z "$TMO" ]; then TMO=none   # Windows has an unrelated timeout.exe (a pause command): require coreutils'
    if timeout --version 2>/dev/null | grep -qi coreutils; then TMO=timeout
    elif gtimeout --version 2>/dev/null | grep -qi coreutils; then TMO=gtimeout
    elif command -v perl >/dev/null 2>&1; then TMO=perl; fi
  fi
  case $TMO in
    timeout|gtimeout) "$TMO" "$s" "$@";;
    perl) perl -e 'alarm shift; exec @ARGV' "$s" "$@";;
    *) "$@";;
  esac; }
fetch1(){ tmo 20 git -C "$ROOT" -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=10 \
  fetch -q "$R" "+refs/heads/$BR:$RREF" >/dev/null 2>&1; }
fetch(){ [ -n "$R" ] || return 0; fetch1 || { sleep 1; fetch1; }; }
push1(){ tmo 20 git -C "$ROOT" push -q "$R" "refs/heads/$BR:refs/heads/$BR" >/dev/null 2>&1; }  # from ROOT: relative remote URLs resolve
rref(){ gm rev-parse -q --verify "$RREF" 2>/dev/null; }
ff_state(){ [ -z "$(g status --porcelain 2>/dev/null)" ] && g merge -q --ff-only "$RREF" >/dev/null 2>&1; return 0; }

lock(){ local i=0 p
  until mkdir "$LOCK" 2>/dev/null; do
    p=$(cat "$LOCK/pid" 2>/dev/null || true)
    if [ -n "$p" ] && ! kill -0 "$p" 2>/dev/null; then rm -rf "$LOCK"; continue; fi
    i=$((i+1)); [ $i -ge 60 ] && die "hk: busy (another hk.sh is running; delete $LOCK if stuck)"
    sleep 0.5
  done
  echo $$ > "$LOCK/pid"; trap 'rm -rf "$LOCK"' EXIT; }
trylock(){ # dir: take it if free or if its holder died; never waits
  mkdir "$1" 2>/dev/null && { echo $$ > "$1/pid"; return 0; }
  local p; p=$(cat "$1/pid" 2>/dev/null || true)
  [ -n "$p" ] && ! kill -0 "$p" 2>/dev/null && rm -rf "$1" && mkdir "$1" 2>/dev/null && { echo $$ > "$1/pid"; return 0; }
  return 1; }
unlock(){ [ "$(cat "$1/pid" 2>/dev/null)" = "$$" ] && rm -rf "$1"; return 0; }
CUR=$H/.cur.lock
curlock(){ local i=0; until trylock "$CUR"; do i=$((i+1)); [ $i -ge "${1:-8}" ] && return 1; sleep 0.25; done; }
curunlock(){ unlock "$CUR"; }

inited(){ [ -n "$ME" ] && [ -e "$WT/.git" ]; }
need(){ inited || die "hk: not set up in this clone. Run: bash .hackathon/bin/hk.sh init <yourname>"; }
valid_id(){ printf '%s' "$1" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$' && [ "$1" != id ] || die "hk: bad task id '$1' (letters, digits, . _ -)"; }
oneline(){ printf '%s' "$*" | tr '\r\n\t' '   '; }
cell(){ oneline "$*" | tr '|' '/'; }
stamp(){ date +%H:%M; }
now(){ date +%s; }
cursors_set(){ local h; h=$(g rev-parse HEAD 2>/dev/null) || return 0; echo "$h" > "$H/.seen"; echo "$h" > "$H/.ucur"; }
setup_cfg(){ # local-only config: merge driver (absolute path; git runs it from the state checkout) + ignore
  local q x; q=$(printf '%s' "$SELF" | sed "s/'/'\\\\''/g")
  gm config merge.hkboard.name "hackathon board row merge"
  gm config merge.hkboard.driver "bash '$q' _mergeboard %O %A %B"
  gm check-ignore -q "$WT/" 2>/dev/null && return 0
  x=$(gm rev-parse --git-path info/exclude); case $x in /*) ;; *) x=$ROOT/$x;; esac
  mkdir -p "$(dirname "$x")"; echo "/.hackathon/state/" >> "$x"; }
bg(){ if command -v nohup >/dev/null 2>&1; then nohup bash "$SELF" "$@" >/dev/null 2>&1 </dev/null &
  else bash "$SELF" "$@" >/dev/null 2>&1 </dev/null & fi; }
bg_fetch_maybe(){ local last t; last=$(cat "$H/.fetched" 2>/dev/null || echo 0); t=$(now)
  [ $((t - last)) -ge "${HK_FETCH_EVERY:-20}" ] || return 0; echo "$t" > "$H/.fetched"; bg _bgfetch; }
json_ctx(){ # event text -> hookSpecificOutput JSON with additionalContext
  local esc; esc=$(printf '%s' "$2" | tr '\t' ' ' | tr -d '\000-\010\013\014\016-\037' \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk 'BEGIN{ORS=""} NR>1{print "\\n"} {print}')
  printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$1" "$esc"; }

# ---- board: markdown table, columns found by header name (| id | owner | status | deps | ref |) ----
AWKLIB='function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function hdr(   i){ if ($0 ~ /^\|/ && trim($2) == "id") { for (i = 2; i < NF; i++) C[trim($i)] = i; return 1 } return 0 }
function isrow(   k){ if (!("id" in C) || $0 !~ /^\|/) return 0; k = trim($2); return k != "" && k !~ /^-+$/ }'
get(){ awk -F'|' -v id="$1" -v n="$2" "$AWKLIB"'
  hdr() { next } isrow() && trim($2) == id { if (n in C) print trim($(C[n])); exit }' "$WT/BOARD.md"; }
setcol(){ HK_ID=$1 HK_N=$2 HK_V=$3 awk -F'|' -v OFS='|' "$AWKLIB"'
  hdr() { print; next }
  isrow() && trim($2) == ENVIRON["HK_ID"] && (ENVIRON["HK_N"] in C) { $(C[ENVIRON["HK_N"]]) = " " ENVIRON["HK_V"] " " }
  { print }' "$WT/BOARD.md" > "$WT/BOARD.md.tmp" && mv "$WT/BOARD.md.tmp" "$WT/BOARD.md"; }
open_tasks(){ awk -F'|' -v now="$(now)" -v lim=$((STALE_MIN*60)) "$AWKLIB"'
  FILENAME == ARGV[1] { if ($0 ~ /^\|/) { k = trim($2); if (k != "id" && k !~ /^-+$/) last[k] = trim($3) } next }
  hdr() { next }
  isrow() { s = trim($(C["status"])); if (s == "done") next
    o = trim($(C["owner"])); line = $0
    if (s == "doing" && (o in last) && now - last[o] > lim) line = line "  STALE (@" substr(o, 2) " inactive " int((now - last[o]) / 60) "m)"
    print line }' "$WT/SEEN.md" "$WT/BOARD.md"; }
is_stale(){ open_tasks | awk -F'|' -v id="$1" '{k=$2; gsub(/ /,"",k)} k==id && /STALE/ {f=1} END{exit !f}'; }
upsert(){ # file key value: set column 2 of the row keyed by column 1 (append if missing)
  if grep -q "^| $2 |" "$WT/$1" 2>/dev/null; then
    HK_K="$2" HK_V="$3" awk -F'|' -v OFS='|' '{k=$2; gsub(/^[ \t]+|[ \t]+$/,"",k)}
      k==ENVIRON["HK_K"] {$3=" " ENVIRON["HK_V"] " "} {print}' "$WT/$1" > "$WT/$1.tmp" && mv "$WT/$1.tmp" "$WT/$1"
  else echo "| $2 | $3 |" >> "$WT/$1"; fi; }
touch_seen(){ local t; t=$(now); upsert SEEN.md "@$ME" "$t"; echo "$t" > "$H/.beat"; }
ensure_layout(){ # create/upgrade state files (v2 boards gain a deps column; SEEN.md added)
  local ch=0
  [ -f "$WT/SEEN.md" ] || { printf '| id | seen |\n|---|---|\n' > "$WT/SEEN.md"; ch=1; }
  [ -f "$WT/MODE.md" ] || { printf '| id | value |\n|---|---|\n| auto | off |\n| auto_until | 0 |\n| solo | - |\n| solo_until | 0 |\n' > "$WT/MODE.md"; ch=1; }
  grep -q '^MODE.md ' "$WT/.gitattributes" 2>/dev/null || { echo 'MODE.md merge=hkboard' >> "$WT/.gitattributes"; ch=1; }
  grep -q '^SEEN.md ' "$WT/.gitattributes" 2>/dev/null || { echo 'SEEN.md merge=hkboard' >> "$WT/.gitattributes"; ch=1; }
  grep -q '^\* text eol=lf' "$WT/.gitattributes" 2>/dev/null || { echo '* text eol=lf' >> "$WT/.gitattributes"; ch=1; }
  if ! awk -F'|' "$AWKLIB"' hdr() { if ("deps" in C) f = 1; exit } END { exit !f }' "$WT/BOARD.md"; then
    awk -F'|' -v OFS='|' "$AWKLIB"'
      hdr() { s = C["status"]; $s = $s "| deps "; print; next }
      ("status" in C) && $0 ~ /^\|/ { s = C["status"]; if (trim($2) ~ /^-+$/) $s = $s "|---"; else $s = $s "| - "; print; next }
      { print }' "$WT/BOARD.md" > "$WT/BOARD.md.tmp" && mv "$WT/BOARD.md.tmp" "$WT/BOARD.md"; ch=1
  fi
  [ $ch = 0 ] || { g add -A && g commit -qm "layout v3 ($ME)" >/dev/null; }; }

# ---- modes: autonomous (team switch + per-person override) and solo ----
mode_get(){ awk -F'|' -v k="$1" '{x=$2; gsub(/^[ \t]+|[ \t]+$/,"",x)} x==k {v=$3; gsub(/^[ \t]+|[ \t]+$/,"",v); print v; exit}' "$WT/MODE.md" 2>/dev/null; }
hm(){ date -d "@$1" +%H:%M 2>/dev/null || date -r "$1" +%H:%M 2>/dev/null; }
dur(){ # 90m / 2h / 30s / bare minutes -> seconds
  case $1 in *[!0-9smh]*|'') return 1;; *h) echo $(( ${1%h} * 3600 ));; *m) echo $(( ${1%m} * 60 ));; *s) echo "${1%s}";; *) echo $(( $1 * 60 ));; esac; }
eff_auto(){ # "on <until-epoch|0>" or "off <why>" for MY agent
  local solo loc u m t; t=$(now)
  m=$(mins_left); [ -n "$m" ] && [ "$m" -le 0 ] && { echo "off deadline"; return; }
  solo=$(mode_get solo); loc=$(cat "$H/.auto" 2>/dev/null || true)
  if [ -n "$solo" ] && [ "$solo" != - ]; then
    [ "$solo" = "@$ME" ] || { echo "off solo-other"; return; }
    [ "${loc%% *}" = off ] && { echo "off local"; return; }
    u=$(mode_get solo_until)
  elif [ -n "$loc" ]; then
    [ "${loc%% *}" = on ] || { echo "off local"; return; }; u=${loc#on }; [ "$u" = on ] && u=0
  else
    [ "$(mode_get auto)" = on ] || { echo "off team"; return; }; u=$(mode_get auto_until)
  fi
  u=${u:-0}; [ "$u" != 0 ] && [ "$t" -ge "$u" ] && { echo "off budget"; return; }
  echo "on $u"; }
auto_on(){ [ "$(eff_auto | cut -d' ' -f1)" = on ]; }
mode_line(){ # what the agent is told at session start / in status
  local st solo u; st=$(eff_auto); solo=$(mode_get solo)
  if [ -n "$solo" ] && [ "$solo" != - ]; then
    if [ "$solo" = "@$ME" ]; then echo "SOLO MODE: you (@$ME) finish alone. You may edit any file, change contracts and take any task; nobody else is working."
    else echo "SOLO MODE: $solo is finishing alone; team notifications are muted for you. Work only if your human asks, and keep out of files $solo is changing."; fi
  fi
  if [ "${st%% *}" = on ]; then u=${st#on }; [ "$u" = 0 ] && u="" || u=" until $(hm "$u")"
    echo "AUTONOMOUS MODE ON$u: don't wait for or ask the human. Decide, log it with hk.sh decide, and keep going until your work runs out (rules in CLAUDE.md)."; fi; }
next_step(){ # the next concrete thing an autonomous agent should do, or nothing when work has run out
  local solo nx last ld lr
  solo=$(mode_get solo)
  if [ "$solo" = "@$ME" ]; then
    nx=$(awk -F'|' -v me="@$ME" "$AWKLIB"' hdr() { next } isrow() && trim($(C["status"])) != "done" {
      o = trim($(C["owner"])); id = trim($2); r = trim($(C["ref"]))
      if (o == me) { print "Finish task " id " (" r "), then /handoff " id " <path:line>."; exit }
      if (!f) f = "Task " id " (" r ", owner " o ") is still open: take it with hk.sh claim " id " and finish it." }
      END { if (f) print f }' "$WT/BOARD.md" | head -n1)
  else
    nx=$(awk -F'|' -v me="@$ME" "$AWKLIB"' hdr() { next }
      isrow() { id = trim($2); st[id] = trim($(C["status"])); ow[id] = trim($(C["owner"])); dp[id] = trim($(C["deps"])); rf[id] = trim($(C["ref"])); ord[++n] = id }
      END { for (i = 1; i <= n; i++) { id = ord[i]; if (ow[id] == me && st[id] != "done") { print "Finish your task " id " (" rf[id] "), then /handoff " id " <path:line>."; exit } }
        for (i = 1; i <= n; i++) { id = ord[i]; if (st[id] != "todo" || ow[id] != "-") continue
          ok = 1; k = split(dp[id], d, ","); for (j = 1; j <= k; j++) if (d[j] != "-" && d[j] != "" && st[d[j]] != "done") ok = 0
          if (ok) { print "Claim the next task: bash .hackathon/bin/hk.sh claim " id " (" rf[id] "), then build it with /slice."; exit } } }' "$WT/BOARD.md")
  fi
  [ -n "$nx" ] && { echo "$nx"; return; }
  ld=$(grep -n ' DEMO ' "$WT/LOG.md" 2>/dev/null | tail -n1); lr=$(grep -n ' DONE ' "$WT/LOG.md" 2>/dev/null | tail -n1 | cut -d: -f1)
  last=${ld#*:}
  case $last in
    *" DEMO RED"*) echo "The demo is RED ($last). Fix it if the failing step is yours (or you're solo); then /demo-check." ;;
    *) url=$(grep -iE '^- *(Live URL|Dev command)' "$H/PLAN.md" 2>/dev/null | sed 's/^[^:]*://' | tr -d '[:space:]')
       if [ -n "$url" ] && [ -n "$lr" ] && { [ -z "$ld" ] || [ "${ld%%:*}" -lt "$lr" ]; }; then echo "All tasks are done but the demo hasn't been checked since: run /demo-check."; fi ;;
  esac; }
mode_publish(){ # "k=v k=v" "log line": team-wide mode change; needs the remote so everyone sees it
  local kv attempt rc before
  need; lock
  for attempt in 1 2 3 4 5; do
    before=$(rref); state_pull; rc=$?
    [ $rc = 1 ] && die "OFFLINE: can't reach '$R'. Mode NOT changed (teammates wouldn't see it); retry when online."
    [ $rc = 2 ] && { conflict_msg; exit 1; }
    ensure_layout
    for kv in $1; do upsert MODE.md "${kv%%=*}" "${kv#*=}"; done
    logline "$2"; touch_seen
    g add -A && g commit -qm "mode ($ME)" >/dev/null || die "hk: commit failed"
    [ -n "$R" ] || { echo "$2 (no remote: local only)"; return 0; }
    push1 && { announce "$before"; echo "$2"; return 0; }
    g reset -q --hard HEAD~1
  done
  die "mode NOT changed: push kept failing. Run hk.sh sync and retry."; }
AUTO_WARN="Note: autonomous agents approve their own permission prompts (the deny list still blocks force-push, rm -rf / and .env reads) and act on teammates' board messages without asking anyone. For long unattended runs prefer a container. Stop it any time: hk.sh auto off (team) / --me."

# ---- events: news between two state commits, then routing (urgent / fyi / escalate) ----
news(){ # teammates' added lines between $1 and $2: log + decisions lines, and open task rows
  [ -n "$1" ] && g cat-file -e "$1^{commit}" 2>/dev/null || return 0
  { g diff -U0 "$1" "$2" -- LOG.md DECISIONS.md 2>/dev/null | grep -E '^\+([^+]|$)' | sed 's/^+//'
    g diff -U0 "$1" "$2" -- BOARD.md 2>/dev/null | grep -E '^\+\|' | sed 's/^+//' | grep -E '^\|[^|]*\| *- *\|'
  } | grep -v -e "^[0-9:]* @$ME " -e '^[[:space:]]*$' || true; }
owners(){ # "dir @name" pairs from the Owners line in PLAN.md
  grep -i '^- *Owners' "$H/PLAN.md" 2>/dev/null | head -n1 | sed 's/^[^:]*://' | tr ',' '\n' \
    | sed -n 's/^[[:space:]]*\([^[:space:]]*\)[[:space:]]*->[[:space:]]*\(@[a-z0-9_-]*\).*/\1 \2/p'; }
mins_left(){ bash "$CLOCK" --minutes 2>/dev/null; }
route(){ # tag each new line: "U " urgent for me, "E " escalate (2nd round trip), "F " fyi
  local n mine deps refs dirs touched late answered m solo am
  n=$(news "$1" "$2"); [ -n "$n" ] || return 0
  mine=$(awk -F'|' -v me="@$ME" "$AWKLIB"' hdr() { next } isrow() && trim($(C["owner"])) == me && trim($(C["status"])) != "done" { print trim($2) }' "$WT/BOARD.md")
  deps=$(for t in $mine; do get "$t" deps; done | tr ',' ' ' | tr -s ' ' '\n' | grep -v '^-*$' | sort -u)
  refs=$(for t in $mine $deps; do get "$t" ref; done | tr -s ' ' '\n' | grep -v '^-*$' | sort -u | tr '\n' ' ')
  dirs=$(owners | awk -v me="@$ME" '$2==me {printf "%s ", $1}')
  touched=$({ gm diff --name-only HEAD 2>/dev/null; gm diff --name-only '@{u}..HEAD' 2>/dev/null; } | sort -u | tr '\n' ' ')
  m=$(mins_left); late=0; [ -n "$m" ] && [ "$m" -le 240 ] && late=1
  solo=$(mode_get solo); solo=${solo:--}; am=off; auto_on && am=on
  answered=$(awk -v me="$ME" -v nowm="$(date +%H:%M)" '
    function mins(t,  a) { split(t, a, ":"); return a[1] * 60 + a[2] }
    $2 == "@" me && $3 == "ANSWER" && (mins(nowm) - mins($1) + 1440) % 1440 <= 30 { x = $4; sub(/:$/, "", x); printf " %s ", x }' "$WT/LOG.md")
  printf '%s\n' "$n" | awk -v me="@$ME" -v deps=" $(echo $deps) " -v refs="$refs" -v dirs="$dirs" \
      -v touched="$touched" -v late="$late" -v answered="$answered" -v solo="$solo" -v am="$am" '
    function under(p, list,   k, a, i) { k = split(list, a, " ")
      for (i = 1; i <= k; i++) if (a[i] != "" && (index(p, a[i]) == 1 || index(a[i], p) == 1)) return 1; return 0 }
    {
      line = $0; c = "F"
      k = split(line, w, " "); actor = w[2]; verb = w[3]; arg = w[4]; a2 = arg; sub(/:$/, "", a2)
      if (line !~ /^\|/ && (verb == "AUTO" || verb == "SOLO")) { print "U " line; next }   # mode changes reach everyone
      if (solo != "-" && solo != me) { print "M " line; next }                              # muted: someone else is solo
      if (line ~ /^\|/) { print "F " line; next }
      if (solo == me) { print ((verb == "NOTE" && a2 == me) ? "U " : "F ") line; next }     # solo: only human notes are urgent
      if (verb == "ESCALATE") c = (am == "on" && arg == me) ? "U" : "F"                    # autonomous asker decides itself
      else if (verb == "ASK" && a2 == me) c = index(answered, " " actor " ") ? "E" : "U"
      else if (verb == "DONE" && index(deps, " " arg " ")) c = "U"
      else if (verb == "CONTRACT-CHANGED") { for (i = 4; i <= k; i++) if (w[i] ~ /\// && under(w[i], refs)) c = "U" }
      else if (verb == "CLAIM-FILE") { if (under(arg, touched) || under(arg, dirs)) c = "U" }
      else if (verb == "DEMO" && arg == "RED") c = late ? "U" : "F"
      else if ((" " line " ") ~ ("[ (]" me "[ :,.;)]")) c = "U"
      print c " " line
    }'; }
escalate(){ # log one ESCALATE line per second-round ASK (humans decide); never wakes anyone
  printf '%s\n' "$1" | sed -n 's/^E //p' | while IFS= read -r l; do
    actor=$(printf '%s' "$l" | awk '{print $2}'); q=$(printf '%s' "$l" | cut -d' ' -f5-)
    bg log "ESCALATE $actor -> @$ME (2nd ASK, humans decide): $q"
  done; }
tagged(){ printf '%s\n' "$2" | sed -n "s/^$1 //p"; }

# ---- publishing state + Discord ----
commit_stray(){ [ -n "$(g status --porcelain 2>/dev/null)" ] || return 0
  g add -A && g commit -qm "edit ($ME)" || die "hk: can't commit in $WT (is git user.name/email set?)"; }
state_pull(){ # 0 ok, 1 offline, 2 local pending commits conflict with remote
  commit_stray
  [ -n "$R" ] || return 0
  fetch || return 1
  rref >/dev/null || return 0
  g rebase -q "$RREF" >/dev/null 2>&1 && return 0
  g rebase --abort >/dev/null 2>&1; return 2; }
ahead(){ [ -n "$R" ] || { echo 0; return; }
  if rref >/dev/null; then g rev-list --count "$RREF..HEAD"; else g rev-list --count HEAD; fi; }
own_lines(){ # my LOG/DECISIONS lines added between $1 and HEAD
  [ -n "$1" ] && g cat-file -e "$1^{commit}" 2>/dev/null || return 0
  g diff -U0 "$1" HEAD -- LOG.md DECISIONS.md 2>/dev/null | grep -E '^\+[0-9]' | sed 's/^+//' | grep "^[0-9:]* @$ME " || true; }
GCONF=${XDG_CONFIG_HOME:-$HOME/.config}/hackathon-harness
discord_url(){ local u; u=$(cat "$H/.discord" 2>/dev/null || true)
  [ "$u" = off ] && return 1
  [ -n "$u" ] || u=$(cat "$GCONF/discord" 2>/dev/null || true)
  [ -n "$u" ] && printf '%s' "$u"; }
announce(){ discord_url >/dev/null || return 0; local l; l=$(own_lines "$1"); [ -n "$l" ] && bg _post "$l"; return 0; }
jesc(){ printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk 'BEGIN{ORS=""} NR>1{print "\\n"} {print}'; }
dpost(){ # url json -> prints the response body, then the HTTP status on the last line
  printf '%s' "$2" | curl -s -m 10 -w '\n%{http_code}' -H 'Content-Type: application/json' --data-binary @- "$1" 2>/dev/null || echo 000; }
project_title(){ local n; n=$(gm remote get-url "$R" 2>/dev/null | sed -e 's#/*$##' -e 's#.*[/:]##' -e 's#\.git$##')
  [ -n "$n" ] || n=$(basename "$ROOT"); printf '%s · %s' "$n" "$(date +%Y-%m-%d)"; }
publish(){ # push local state commits; 0 pushed, 1 offline, 2 conflict
  [ -n "$R" ] || return 0
  local i rc before; before=$(rref)
  for i in 1 2 3 4 5; do
    push1 && { announce "$before"; return 0; }
    state_pull; rc=$?; [ $rc -ne 0 ] && return $rc
  done; return 1; }
conflict_msg(){ echo "STATE CONFLICT: your unpushed board edits clash with a teammate's edit of the same row."
  echo "  Fix: cd .hackathon/state && git rebase $R/$BR (resolve BOARD.md, git rebase --continue), then hk.sh sync"; }
report(){ case $1 in
    0) echo "$2";;
    1) echo "$2 - NOT PUSHED (remote unreachable). Saved locally; hk.sh sync will retry."; exit 2;;
    *) echo "$2 - NOT PUSHED."; conflict_msg; exit 2;;
  esac; }
prep(){ need; lock; state_pull; case $? in 2) conflict_msg; exit 1;; esac; ensure_layout; }
logline(){ echo "$(stamp) @$ME $(oneline "$*")" >> "$WT/LOG.md"; }
save(){ touch_seen; g add -A && g commit -qm "$1 ($ME)" >/dev/null || die "hk: commit failed"; publish; report $? "$2"; }

case "$CMD" in
init)
  name=$(printf '%s' "${1:-}" | tr 'A-Z' 'a-z')
  printf '%s' "$name" | grep -Eq '^[a-z0-9][a-z0-9_-]*$' || die "usage: hk.sh init <name>   (letters, digits, _ -)"
  gm rev-parse -q --verify HEAD >/dev/null || die "hk: commit something first (the harness files are fine)."
  gm var GIT_COMMITTER_IDENT >/dev/null 2>&1 || die "hk: set git user.name and user.email first."
  lock; mkdir -p "$H"; printf '%s\n' "$name" > "$H/.me"; ME=$name
  hp=$(gm config core.hooksPath || true)
  if [ -z "$hp" ] || [ "$hp" = .githooks ]; then gm config core.hooksPath .githooks; hookmsg="git hooks enabled (pre-push check, contract alerts, activity)"
  else hookmsg="core.hooksPath is '$hp' (left alone: no pre-push check, contract alerts or activity beats)"; fi
  setup_cfg
  if [ ! -e "$WT/.git" ]; then
    [ -d "$WT" ] && { rmdir "$WT" 2>/dev/null || die "hk: $WT exists and is not a state checkout; move it away."; }
    gm worktree prune
    remote_has=1
    if [ -n "$R" ]; then
      tmo 20 git -C "$ROOT" ls-remote --exit-code "$R" "refs/heads/$BR" >/dev/null 2>&1; rc=$?
      case $rc in 0) remote_has=0;; 2) ;; *) die "hk: can't reach remote '$R'. Check network/auth, then re-run init.";; esac
    fi
    if [ $remote_has = 0 ]; then
      fetch || die "hk: fetch from '$R' failed; re-run init."
      gm worktree add -q -B "$BR" "$WT" "$RREF" || die "hk: worktree add failed"
    elif gm rev-parse -q --verify "refs/heads/$BR" >/dev/null; then
      gm worktree add -q "$WT" "$BR" || die "hk: worktree add failed"
    else
      gm worktree add -q --detach "$WT" HEAD || die "hk: worktree add failed"
      g checkout -q --orphan "$BR" && g rm -rqf . >/dev/null
      printf '| id | owner | status | deps | ref |\n|---|---|---|---|---|\n' > "$WT/BOARD.md"
      : > "$WT/LOG.md"; echo "# Decisions (one line each, never re-argue)" > "$WT/DECISIONS.md"
      printf '| id | seen |\n|---|---|\n' > "$WT/SEEN.md"
      printf '* text eol=lf\nBOARD.md merge=hkboard\nSEEN.md merge=hkboard\nLOG.md merge=union\nDECISIONS.md merge=union\n' > "$WT/.gitattributes"
      g add -A && g commit -qm "hackathon state: init ($ME)" || die "hk: initial state commit failed"
      if [ -n "$R" ] && ! push1; then   # someone created it at the same moment: use theirs
        fetch && rref >/dev/null && g reset -q --hard "$RREF" \
          || echo "warning: couldn't push the new state branch; hk.sh sync will retry."
      fi
    fi
  fi
  ensure_layout; [ "$(ahead)" -gt 0 ] && publish
  cursors_set
  echo "ok: you are @$ME. Board: .hackathon/state/BOARD.md (branch $BR${R:+ on $R}). $hookmsg." ;;

sync)
  if ! inited; then [ "${1:-}" = --hook ] && exit 0; need; fi
  lock; setup_cfg; state_pull; rc=$?
  case $rc in 1) echo "OFFLINE: can't reach '$R'; showing the last known board.";; 2) conflict_msg;; esac
  ensure_layout
  if [ $rc -eq 0 ] && [ "$(ahead)" -gt 0 ]; then publish && echo "pushed pending board/log updates" || echo "pending updates still not pushed"; fi
  rt=$(route "$(cat "$H/.seen" 2>/dev/null || true)" HEAD)
  escalate "$(route "$(cat "$H/.ucur" 2>/dev/null || true)" HEAD)"
  cursors_set
  u=$(tagged U "$rt"); f=$(tagged F "$rt"); e=$(tagged E "$rt")
  [ "${1:-}" = --hook ] && { echo "TEAM: you are @$ME; lines addressed to @$ME are for you."; mode_line; }
  [ -n "$u" ] && { echo "URGENT FOR YOU (@$ME):"; echo "$u"; }
  [ -n "$f$e" ] && { echo "NEW:"; [ -n "$f" ] && echo "$f"; [ -n "$e" ] && printf '%s\n' "$e" | sed 's/^/ESCALATED (humans decide): /'; }
  t=$(open_tasks); echo "OPEN TASKS:"; echo "${t:-(none)}" ;;

peek) # every prompt: urgent + fyi lines since last look (from the last background fetch); never blocks
  inited && [ -n "$R" ] || exit 0
  r=$(rref)
  if [ -n "$r" ] && curlock; then
    s=$(cat "$H/.seen" 2>/dev/null || true); u=$(cat "$H/.ucur" 2>/dev/null || true); ru=""; rf=""
    [ "$r" != "$u" ] && ru=$(route "$u" "$r")
    [ "$r" != "$s" ] && rf=$(route "$s" "$r")
    echo "$r" > "$H/.seen"; echo "$r" > "$H/.ucur"; curunlock
    escalate "$ru"
    U=$(tagged U "$ru"); F=$(tagged F "$rf"); E=$(tagged E "$rf")
    [ -n "$U" ] && { echo "TEAM URGENT for you (@$ME) - act only if it affects your task:"; echo "$U"; }
    [ -n "$F$E" ] && { echo "TEAM UPDATES:"; [ -n "$F" ] && echo "$F"; [ -n "$E" ] && printf '%s\n' "$E" | sed 's/^/ESCALATED (humans decide): /'; }
  fi
  bg_fetch_maybe; exit 0 ;;

posttool) # after every tool call: inject urgent lines mid-turn (cheap; no network in this process)
  inited && [ -n "$R" ] || exit 0
  input=""; [ -t 0 ] || input=$(tmo 2 cat)   # hook JSON on stdin; never block on an open pipe
  printf '%s' "$input" | grep -q '"agent_id"[[:space:]]*:[[:space:]]*"[^"]' && exit 0   # inside a subagent: leave it for the main agent
  bg_fetch_maybe
  r=$(rref) || exit 0; u=$(cat "$H/.ucur" 2>/dev/null || true)
  [ "$r" = "$u" ] && exit 0
  curlock 1 || exit 0
  u=$(cat "$H/.ucur" 2>/dev/null || true); [ "$r" = "$u" ] && { curunlock; exit 0; }   # re-read under the lock
  ru=$(route "$u" "$r"); echo "$r" > "$H/.ucur"; curunlock
  escalate "$ru"; U=$(tagged U "$ru")
  [ -n "$U" ] && json_ctx PostToolUse "TEAM URGENT for you (@$ME) - act only if it affects your task; don't reply conversationally:
$U"
  exit 0 ;;

watch) # Stop/SessionStart hook with asyncRewake: wait for an urgent event, then exit 2 to wake the agent
  inited && [ -n "$R" ] || exit 0
  pidf=$H/.watch.pid; old=$(cat "$pidf" 2>/dev/null || true)
  if [ -n "$old" ] && [ "$old" != $$ ] && kill -0 "$old" 2>/dev/null && ps -p "$old" -o args= 2>/dev/null | grep -q 'hk.sh watch'; then
    kill "$old" 2>/dev/null; fi
  echo $$ > "$pidf"
  trap 'unlock "$LOCK"; curunlock; [ "$(cat "$pidf" 2>/dev/null)" = "$$" ] && rm -f "$pidf"' EXIT; trap 'exit 0' TERM INT
  end=$(( $(now) + ${HK_WATCH_MAX:-3500} ))
  while [ "$(now)" -lt $end ]; do
    iv=${HK_WATCH_INTERVAL:-}; if [ -z "$iv" ]; then iv=15; m=$(mins_left); [ -n "$m" ] && [ "$m" -le 240 ] && iv=5; fi
    sleep "$iv"   # first: lets the session-start sync / the finished turn settle
    [ "$(cat "$pidf" 2>/dev/null)" = "$$" ] || exit 0   # superseded by a newer watcher
    if trylock "$LOCK"; then fetch; ff_state; unlock "$LOCK"; fi
    r=$(rref); u=$(cat "$H/.ucur" 2>/dev/null || true)
    if [ -n "$r" ] && [ "$r" != "$u" ] && curlock; then
      u=$(cat "$H/.ucur" 2>/dev/null || true)   # re-read under the lock: posttool may have delivered it
      ru=""; [ "$r" != "$u" ] && ru=$(route "$u" "$r"); U=$(tagged U "$ru")
      woke=$(awk -v t="$(now)" '$1 > t - 3600' "$H/.wakes" 2>/dev/null | wc -l | tr -d ' ')
      if [ -z "$U" ] || [ "$woke" -lt "$WAKE_CAP" ]; then echo "$r" > "$H/.ucur"; escalate "$ru"; fi
      curunlock   # over the wake cap: leave the cursor so the next prompt delivers it as urgent
      if [ -n "$U" ] && [ "$woke" -lt "$WAKE_CAP" ]; then
        now >> "$H/.wakes"
        printf 'TEAM URGENT for you (@%s) - this woke you. Act only if it affects your task; otherwise say so in one line and stop:\n%s\n' "$ME" "$U"
        exit 2
      fi
    fi
  done
  exit 0 ;;

pretool) # before Edit/Write: warn once per file if a teammate claimed it or owns its directory;
         # before AskUserQuestion in autonomous mode: refuse, the agent decides itself
  inited || exit 0
  input=""; [ -t 0 ] || input=$(tmo 2 cat)   # hook JSON on stdin; never block on an open pipe
  if printf '%s' "$input" | grep -q '"tool_name"[[:space:]]*:[[:space:]]*"AskUserQuestion"'; then
    auto_on || exit 0
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"AUTONOMOUS MODE: nobody will answer. Pick the option you judge best for the demo, log it with bash .hackathon/bin/hk.sh decide \\"<choice and why>\\", and continue."}}\n'
    exit 0
  fi
  [ "$(mode_get solo)" = "@$ME" ] && exit 0   # solo: you own the whole repo
  f=$(printf '%s' "$input" | tr '\n' ' ' | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
  f=$(printf '%s' "$f" | sed -e 's#\\\\#/#g' -e 's#\\#/#g')   # JSON-escaped and plain backslashes -> /
  case $f in [A-Za-z]:/*)   # Windows drive path -> /c/... like Git Bash's pwd
    if command -v cygpath >/dev/null 2>&1; then f=$(cygpath -u "$f")
    else f="/$(printf '%s' "${f%%:*}" | tr 'A-Z' 'a-z')${f#?:}"; fi;; esac
  case $f in "$ROOT"/*) rel=${f#"$ROOT"/};; "$ROOTL"/*) rel=${f#"$ROOTL"/};; *) exit 0;; esac
  case $rel in .hackathon/*|.claude/*) exit 0;; esac
  grep -qxF -- "$rel" "$H/.warned" 2>/dev/null && exit 0
  who=$(awk -v me="@$ME" -v rel="$rel" -v nowm="$(date +%H:%M)" '
    function mins(t,  a) { split(t, a, ":"); return a[1] * 60 + a[2] }
    $3 == "CLAIM-FILE" && $2 != me && (index(rel, $4) == 1 || index($4, rel) == 1) && (mins(nowm) - mins($1) + 1440) % 1440 <= 180 { w = "claimed by " $2 " at " $1 }
    END { if (w) print w }' "$WT/LOG.md" 2>/dev/null)
  [ -n "$who" ] || who=$(owners | awk -v me="@$ME" -v rel="$rel" '$2 != me && index(rel, $1) == 1 { print "is in " $2 "'"'"'s directory " $1; exit }')
  [ -n "$who" ] || exit 0
  echo "$rel" >> "$H/.warned"
  msg="COLLISION WARNING: $rel $who. Unless the human told you to, don't edit it: pick another file or log \"ASK @owner: ...\" first. (If the human did say so, retry: it will go through.)"
  if [ "${HK_COLLISION:-once}" = warn ]; then json_ctx PreToolUse "$msg"; exit 0; fi
  esc=$(printf '%s' "$msg" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$esc"
  exit 0 ;;

contract) # from pre-push: once the push to main has landed, log which contract files changed
  inited && [ -n "$R" ] || exit 0
  ref=${1:-}; sha=${2:-}; shift 2 2>/dev/null || exit 0; [ $# -gt 0 ] || exit 0
  i=0; while [ $i -lt 30 ]; do
    [ "$(tmo 10 git -C "$ROOT" ls-remote "$R" "$ref" 2>/dev/null | cut -f1)" = "$sha" ] && break
    i=$((i+1)); sleep 2; done
  [ $i -lt 30 ] || exit 0
  exec bash "$SELF" log "CONTRACT-CHANGED $* (${ref#refs/heads/}@$(printf '%.7s' "$sha")): pull and check your side" ;;

_beat) # from post-commit: mark me active (at most every 10 min) for stale-claim detection
  inited || exit 0
  last=$(cat "$H/.beat" 2>/dev/null || echo 0); [ $(( $(now) - last )) -ge "${HK_BEAT_EVERY:-600}" ] || exit 0
  trylock "$LOCK" || exit 0; trap 'unlock "$LOCK"' EXIT
  state_pull; [ $? = 2 ] && exit 0; ensure_layout
  touch_seen; g add -A && g commit -qm "active ($ME)" >/dev/null && publish
  exit 0 ;;

_bgfetch) # fetch, and fast-forward the state checkout if nothing local is pending
  trylock "$LOCK" || exit 0; trap 'unlock "$LOCK"' EXIT
  fetch || exit 0; ff_state; exit 0 ;;

_post) # Discord webhook post (background). Mentions are disabled so nobody gets pinged.
  url=$(discord_url) || exit 0
  text=$(printf '%s\n' "$*" | awk '
    { e = "•"; if ($3 == "DONE") e = "✅"; else if ($3 == "BLOCKED") e = "⛔"; else if ($3 == "ASK") e = "❓";
      else if ($3 == "ANSWER") e = "💬"; else if ($3 == "ESCALATE") e = "🚨"; else if ($3 == "CLAIMED" || $3 == "TOOK-OVER") e = "🙋";
      else if ($3 == "NOTE") e = "📝"; else if ($3 == "CONTRACT-CHANGED") e = "📜"; else if ($3 == "DEMO") e = ($4 == "RED") ? "🔴" : "🟢";
      else if ($3 == "AUTO") e = "🤖"; else if ($3 == "SOLO") e = "🎯"; else if ($3 == "STUCK") e = "🧱";
      if (NR <= 15) print e " " substr($0, 1, 300) }')
  who=${ME:-$(gm config user.name 2>/dev/null | tr 'A-Z ' 'a-z-')}
  who=$(printf '%s' "${who:-hk}" | tr -d '@#:`' | sed 's/[Dd][Ii][Ss][Cc][Oo][Rr][Dd]//g; s/[Cc][Ll][Yy][Dd][Ee]//g'); [ -n "$who" ] || who=hk
  base="\"content\":\"$(jesc "$text")\",\"username\":\"$who\",\"allowed_mentions\":{\"parse\":[]}"
  sep='?'; case $url in *\?*) sep='&';; esac
  tid=""; bad=""; inited && tid=$(mode_get discord_thread)
  case $tid in
    plain) case $(dpost "$url" "{$base}" | tail -n1) in 2*) exit 0;; *) exit 1;; esac ;;
    ''|-) ;;
    *) r=$(dpost "$url${sep}thread_id=$tid" "{$base}"); case $(printf '%s' "$r" | tail -n1) in 2*) exit 0;; esac
       [ -n "${HK_POST_RETRY:-}" ] && exit 0; bad=$tid; tid=""   # post deleted? make a new one (once)
       ;;
  esac
  # No post for this project yet: create it under the lock so teammates don't create two.
  locked=0
  if inited; then i=0; until trylock "$LOCK"; do i=$((i+1)); [ $i -ge 40 ] && break; sleep 0.25; done
    [ $i -lt 40 ] && { locked=1; trap 'unlock "$LOCK"' EXIT; state_pull >/dev/null 2>&1; ensure_layout; tid=$(mode_get discord_thread)
      case $tid in ''|-|"$bad") ;; *) unlock "$LOCK"; HK_POST_RETRY=1 exec bash "$SELF" _post "$@";; esac; }
  fi
  title="$(project_title)"; [ "$text" != "${text#*hk.sh test message}" ] && ! inited && title="hk.sh test"
  r=$(dpost "$url${sep}wait=true" "{$base,\"thread_name\":\"$(jesc "$title")\"}")
  case $(printf '%s' "$r" | tail -n1) in
    2*) tid=$(printf '%s' "$r" | sed -n 's/.*"channel_id"[[:space:]]*:[[:space:]]*"\([0-9][0-9]*\)".*/\1/p' | head -n1) ;;
    4*) r=$(dpost "$url" "{$base}")   # not a forum channel: plain posts from now on
        case $(printf '%s' "$r" | tail -n1) in 2*) tid=plain;; *) tid="";; esac ;;
    *) tid="" ;;
  esac
  [ -n "$tid" ] || exit 1
  if [ $locked = 1 ]; then
    upsert MODE.md discord_thread "$tid"; g add -A && g commit -qm "discord ($ME)" >/dev/null && publish >/dev/null 2>&1; fi
  exit 0 ;;

_mergeboard) # git merge driver: 3-way merge of a table by its first column; only same-row edits conflict
  O=$1 A=$2 B=$3
  awk -F'|' -v O="$O" -v A="$A" '
    function key(l,  p, k) { if (l !~ /^\|/) return ""; split(l, p, "|"); k = p[2]
      gsub(/^[ \t]+|[ \t]+$/, "", k); if (k == "" || k == "id" || k ~ /^-+$/) return ""; return k }
    { f = (FILENAME == O) ? 1 : (FILENAME == A) ? 2 : 3; k = key($0) }
    f == 1 { if (k != "") o[k] = $0; next }
    f == 2 { n++; al[n] = $0; ak[n] = k; if (k != "") a[k] = $0; next }
    { if (k != "") { b[k] = $0; if (!(k in bs)) { nb++; bo[nb] = k; bs[k] = 1 } } }
    END {
      for (i = 1; i <= n; i++) { k = ak[i]
        if (k == "") { out[++m] = al[i]; continue }
        if (k in o) {
          if (!(k in b)) { if (a[k] != o[k]) bad = 1; else continue }
          else if (a[k] == o[k]) { out[++m] = b[k]; continue }
          else if (b[k] != o[k] && b[k] != a[k]) bad = 1
        } else if ((k in b) && b[k] != a[k]) bad = 1
        out[++m] = a[k] }
      for (j = 1; j <= nb; j++) { k = bo[j]; if (k in a) continue
        if (k in o) { if (b[k] != o[k]) bad = 1; continue }
        out[++m] = b[k] }
      if (bad) exit 1
      for (i = 1; i <= m; i++) print out[i] }' "$O" "$A" "$B" > "$A.hkmerge" \
    && mv "$A.hkmerge" "$A" || { rm -f "$A.hkmerge"; exit 1; } ;;

claim)
  id=${1:-}; valid_id "$id"; take=0; [ "${2:-}" = --take ] && take=1; need; lock
  for attempt in 1 2 3 4 5; do
    before=$(rref)
    state_pull; rc=$?
    [ $rc = 1 ] && die "OFFLINE: can't reach '$R'. Claim NOT made (the remote is the lock); retry when online."
    [ $rc = 2 ] && { conflict_msg; exit 1; }
    ensure_layout
    [ -n "$(get "$id" id)" ] || die "no task '$id' on the board (add it: hk.sh add $id <ref>)"
    owner=$(get "$id" owner); status=$(get "$id" status)
    [ "$owner" = "@$ME" ] && { echo "ALREADY YOURS: $id"; exit 0; }
    [ "$status" = "done" ] && die "ALREADY DONE: $id"
    ev="CLAIMED $id"
    if [ "$owner" != "-" ] && [ -n "$owner" ]; then
      if [ "$(mode_get solo)" = "@$ME" ]; then ev="TOOK-OVER $id from $owner (solo)"
      elif [ $take = 1 ]; then
        is_stale "$id" || die "NOT STALE: $owner is still active on $id (stale after ${STALE_MIN}m of no commits/board activity)"
        ev="TOOK-OVER $id from $owner (stale)"
      else
        [ $attempt -gt 1 ] && die "LOST RACE: $owner claimed $id first. Pick another task."
        is_stale "$id" && die "TAKEN by $owner, but STALE: take it over with hk.sh claim $id --take"
        die "TAKEN by $owner"
      fi
    fi
    setcol "$id" owner "@$ME"; setcol "$id" status doing; logline "$ev"; touch_seen
    g add -A && g commit -qm "claim $id ($ME)" >/dev/null || die "hk: commit failed"
    [ -n "$R" ] || { echo "CLAIMED $id (no remote: local only)"; exit 0; }
    push1 && { announce "$before"; echo "${ev%% (*}"; exit 0; }
    g reset -q --hard HEAD~1   # drop our claim, re-read the latest board, try again
  done
  die "claim NOT made: push kept failing. Run hk.sh sync and retry." ;;

release)
  id=${1:-}; valid_id "$id"; prep
  [ -n "$(get "$id" id)" ] || die "no task '$id'"
  [ "$(get "$id" owner)" = "@$ME" ] || die "not yours: $id is owned by $(get "$id" owner)"
  setcol "$id" owner -; setcol "$id" status todo; logline "RELEASED $id"
  save "release $id" "RELEASED $id" ;;

done)
  id=${1:-}; valid_id "$id"; ref=$(cell "${2:--}"); prep
  [ -n "$(get "$id" id)" ] || die "no task '$id'"
  owner=$(get "$id" owner)
  [ "$owner" = "@$ME" ] || [ "$owner" = "-" ] || die "not yours: $id is owned by $owner"
  setcol "$id" owner "@$ME"; setcol "$id" status "done"; setcol "$id" ref "$ref"; logline "DONE $id -> $ref"
  save "done $id" "DONE $id" ;;

add)
  id=${1:-}; valid_id "$id"; shift; ref=-; after=-
  while [ $# -gt 0 ]; do case $1 in --after) after=$(printf '%s' "${2:-}" | tr -d ' |'); shift 2;; *) ref=$(cell "$1"); shift;; esac; done
  [ -n "$after" ] || after=-
  prep
  [ -z "$(get "$id" id)" ] || die "task '$id' already exists"
  for d in $(printf '%s' "$after" | tr ',' ' '); do [ "$d" = - ] || [ -n "$(get "$d" id)" ] || die "no task '$d' to depend on"; done
  [ -z "$(tail -c1 "$WT/BOARD.md")" ] || echo >> "$WT/BOARD.md"
  row=$(awk -F'|' -v id="$id" -v ref="$ref" -v after="$after" "$AWKLIB"'
    hdr() { line = "|"; for (i = 2; i < NF; i++) { c = trim($i); v = "-"
      if (c == "id") v = id; else if (c == "status") v = "todo"; else if (c == "deps") v = after; else if (c == "ref") v = ref
      line = line " " v " |" } print line; exit }' "$WT/BOARD.md")
  [ -n "$row" ] || die "hk: BOARD.md has no header row"
  echo "$row" >> "$WT/BOARD.md"
  save "add $id" "ADDED $id" ;;

log|note|decide)
  [ $# -gt 0 ] || die "usage: hk.sh $CMD <text>"
  [ "$CMD" = note ] && { printf '%s' "$1" | grep -Eq '^@[a-z0-9_-]+' || die "usage: hk.sh note \"@name text\""; }
  prep
  case $CMD in
    log) logline "$*";;
    note) logline "NOTE $*";;
    decide) echo "$(stamp) @$ME $(oneline "$*")" >> "$WT/DECISIONS.md";;
  esac
  f=LOG.md; [ "$CMD" = decide ] && f=DECISIONS.md
  save "$CMD" "saved to $f" ;;

demo)
  st=$(printf '%s' "${1:-}" | tr 'a-z' 'A-Z'); case $st in GREEN|RED) ;; *) die "usage: hk.sh demo green|red \"<url or failing step>\"";; esac
  shift; prep; logline "DEMO $st $*"; save "demo" "DEMO $st logged" ;;

discord)
  glob=0; [ "${2:-}" = --global ] && glob=1
  usage="usage: hk.sh discord <https://discord.com/api/webhooks/...> [--global] | off [--global] | test | status"
  case "${1:-}" in
    off) if [ $glob = 1 ]; then rm -f "$GCONF/discord"; echo "discord: machine-wide URL removed"
         else echo off > "$H/.discord"; echo "discord: off for this project (a machine-wide URL is ignored here)"; fi ;;
    test) discord_url >/dev/null || die "discord: not set. $usage"
      n=${ME:-$(gm config user.name 2>/dev/null | tr 'A-Z ' 'a-z-')}
      if bash "$SELF" _post "$(stamp) @${n:-me} hk.sh test message"; then echo "discord: test delivered (check the channel)"
      else die "discord: Discord refused the post or couldn't be reached. Check the URL (hk.sh discord status) and your network."; fi ;;
    status) if [ "$(cat "$H/.discord" 2>/dev/null)" = off ]; then echo "discord: off for this project"
      elif [ -s "$H/.discord" ]; then echo "discord: on (this project's URL)"
      elif [ -s "$GCONF/discord" ]; then echo "discord: on (machine-wide URL in $GCONF/discord)"
      else echo "discord: not set"; fi
      t=""; inited && t=$(mode_get discord_thread); case $t in ''|-) echo "post: none yet (created by the first event)";; plain) echo "channel: normal text channel";; *) echo "forum post id: $t";; esac ;;
    https://discord.com/api/webhooks/*|https://discordapp.com/api/webhooks/*|https://canary.discord.com/api/webhooks/*|https://ptb.discord.com/api/webhooks/*)
      if [ $glob = 1 ]; then (umask 077; mkdir -p "$GCONF"; printf '%s\n' "$1" > "$GCONF/discord"); echo "discord: on for every project on this machine ($GCONF/discord). Try: hk.sh discord test"
      else (umask 077; printf '%s\n' "$1" > "$H/.discord"); echo "discord: on for this project (.hackathon/.discord, gitignored). Try: hk.sh discord test"; fi ;;
    *) die "$usage" ;;
  esac ;;

auto)
  sub=${1:-status}; [ $# -gt 0 ] && shift
  me=0; d=10800
  for a in "$@"; do case $a in --me) me=1;; *) d=$(dur "$a") || die "usage: hk.sh auto on [90m|2h] [--me] | off [--me] | clear --me | status";; esac; done
  case $sub in
    on) need; until=$(( $(now) + d ))
      if [ $me = 1 ]; then echo "on $until" > "$H/.auto"; echo "AUTONOMOUS ON for @$ME until $(hm "$until") (this clone only)."
      else mode_publish "auto=on auto_until=$until" "AUTO ON until $(hm "$until") (set by @$ME): agents work without waiting for humans; hk.sh auto off stops them"; fi
      echo "$AUTO_WARN" ;;
    off) need
      if [ $me = 1 ]; then echo off > "$H/.auto"; echo "AUTONOMOUS OFF for @$ME (this clone only, whatever the team setting)."
      else mode_publish "auto=off auto_until=0" "AUTO OFF (by @$ME): agents stop and wait for their humans"; fi ;;
    clear) need; rm -f "$H/.auto"; echo "@$ME follows the team setting again." ;;
    status) need
      echo "team: auto $(mode_get auto)$( u=$(mode_get auto_until); [ "${u:-0}" != 0 ] && echo " until $(hm "$u")"), solo $(mode_get solo)"
      [ -f "$H/.auto" ] && echo "this clone overrides: $(cut -d' ' -f1 "$H/.auto")"
      st=$(eff_auto); echo "you (@$ME): autonomous ${st%% *} (${st#* })"
      mode_line ;;
    *) die "usage: hk.sh auto on [90m|2h] [--me] | off [--me] | clear --me | status" ;;
  esac ;;

solo)
  who=${1:-}; [ $# -gt 0 ] && shift
  case $who in
    off) mode_publish "solo=- solo_until=0" "SOLO OFF (by @$ME): everyone back to normal; check the board with /sync" ;;
    @*) printf '%s' "$who" | grep -Eq '^@[a-z0-9][a-z0-9_-]*$' || die "usage: hk.sh solo @name [2h] | off"
      d=10800; [ $# -gt 0 ] && { d=$(dur "$1") || die "usage: hk.sh solo @name [2h] | off"; }
      need; until=$(( $(now) + d ))
      grep -q "^| $who |" "$WT/SEEN.md" 2>/dev/null || echo "warning: $who hasn't been active on this board yet (typo?)"
      mode_publish "solo=$who solo_until=$until" "SOLO $who until $(hm "$until") (set by @$ME): $who finishes alone, autonomous, and may change anything; everyone else is muted"
      echo "$AUTO_WARN" ;;
    *) die "usage: hk.sh solo @name [2h] | off" ;;
  esac ;;

permit) # PermissionRequest hook: in autonomous mode approve the prompt (deny rules never reach here)
  inited || exit 0
  [ -t 0 ] || tmo 2 cat >/dev/null
  auto_on || exit 0
  printf '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}\n'
  exit 0 ;;

autostop) # Stop hook: in autonomous mode keep the agent going while work remains
  inited || exit 0
  [ -t 0 ] || tmo 2 cat >/dev/null
  st=$(eff_auto); [ "${st%% *}" = on ] || { rm -f "$H/.autofp"; exit 0; }
  nx=$(next_step); [ -n "$nx" ] || { rm -f "$H/.autofp"; exit 0; }   # work ran out: let it stop
  fp=$( { cat "$WT/BOARD.md" "$WT/LOG.md"; gm rev-parse HEAD; gm status --porcelain; } 2>/dev/null | cksum | cut -d' ' -f1)
  pf=""; cnt=0; [ -f "$H/.autofp" ] && read -r pf cnt < "$H/.autofp"
  if [ "$fp" = "$pf" ]; then cnt=$((cnt + 1)); else cnt=0; fi
  if [ "$cnt" -ge "${HK_AUTO_STUCK:-3}" ]; then   # no progress at all: stop instead of spinning, tell the humans
    rm -f "$H/.autofp"; bg log "STUCK (autonomous): no progress after $cnt tries on: $nx"; exit 0; fi
  echo "$fp $cnt" > "$H/.autofp"
  u=${st#on }; [ "$u" = 0 ] && u="" || u=" until $(hm "$u")"
  json_reason=$(printf '%s' "AUTONOMOUS MODE$u: don't stop and don't wait for a human. Next: $nx Decide anything unclear yourself and log it with bash .hackathon/bin/hk.sh decide." | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
  if [ "${HK_STOP_STYLE:-context}" = block ]; then printf '{"decision":"block","reason":"%s"}\n' "$json_reason"
  else printf '{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"%s"}}\n' "$json_reason"; fi
  exit 0 ;;

board) need; cat "$WT/BOARD.md" ;;

*) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
