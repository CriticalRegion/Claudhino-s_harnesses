#!/usr/bin/env bash
# hk.sh - git-backed coordination for a hackathon team (people + their agents).
# Board/log/decisions live on their own branch (hackathon-state), checked out at
# .hackathon/state. Coordination never commits, pushes, pulls or rebases your code.
#
#   init <name>            set your handle, attach (or create) the shared state branch
#   sync [--hook]          refresh the board, push anything pending, print news + open tasks
#   peek                   (prompt hook) print teammates' new lines since last look; never blocks
#   claim <id>             take a task; the remote is the lock (CLAIMED / TAKEN / LOST RACE)
#   release <id>           give a task back
#   done <id> [path:line]  mark your task done and log it
#   add <id> [ref]         add a task row
#   log <text>             append one line to LOG.md      (BLOCKED / ASK @x / UNBLOCKS @x / CLAIM-FILE p)
#   decide <text>          append one line to DECISIONS.md
#   board                  print the board
#
# Exit codes: 0 ok, 1 refused/failed (nothing changed remotely), 2 saved locally but NOT pushed.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd -P) || exit 1
H=$ROOT/.hackathon; WT=$H/state; BR=hackathon-state; LOCK=$H/.lock; SELF=$H/bin/hk.sh
ME=$(cat "$H/.me" 2>/dev/null || true); ME=${ME:-${HK_ME:-}}
export GIT_TERMINAL_PROMPT=0 HK_SKIP=1
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o ConnectTimeout=8}"
CMD=${1:-}; [ $# -gt 0 ] && shift

quiet_cmd(){ [ "$CMD" = peek ] || [ "$CMD" = _bgfetch ] || { [ "$CMD" = sync ] && [ "${1:-}" = --hook ]; }; }
die(){ echo "$*"; exit 1; }
gm(){ git -C "$ROOT" "$@"; }
g(){ git -C "$WT" "$@"; }
if ! gm rev-parse --git-dir >/dev/null 2>&1; then quiet_cmd "$@" && exit 0; die "hk: $ROOT is not a git repo"; fi

R=$(gm config hk.remote 2>/dev/null || true)
if [ -z "$R" ]; then if gm remote | grep -qx origin; then R=origin; else R=$(gm remote | head -n1); fi; fi
RREF=refs/remotes/$R/$BR

tmo(){ local s=$1; shift
  if command -v timeout >/dev/null 2>&1; then timeout "$s" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$s" "$@"
  elif command -v perl >/dev/null 2>&1; then perl -e 'alarm shift; exec @ARGV' "$s" "$@"
  else "$@"; fi; }
fetch1(){ tmo 20 git -C "$ROOT" -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=10 \
  fetch -q "$R" "+refs/heads/$BR:$RREF" >/dev/null 2>&1; }
fetch(){ [ -n "$R" ] || return 0; fetch1 || { sleep 1; fetch1; }; }
push1(){ tmo 20 git -C "$ROOT" push -q "$R" "refs/heads/$BR:refs/heads/$BR" >/dev/null 2>&1; }  # from ROOT: relative remote URLs resolve correctly

lock(){ local i=0 p
  until mkdir "$LOCK" 2>/dev/null; do
    p=$(cat "$LOCK/pid" 2>/dev/null || true)
    if [ -n "$p" ] && ! kill -0 "$p" 2>/dev/null; then rm -rf "$LOCK"; continue; fi
    i=$((i+1)); [ $i -ge 60 ] && die "hk: busy (another hk.sh is running; delete $LOCK if stuck)"
    sleep 0.5
  done
  echo $$ > "$LOCK/pid"; trap 'rm -rf "$LOCK"' EXIT; }

inited(){ [ -n "$ME" ] && [ -e "$WT/.git" ]; }
need(){ inited || die "hk: not set up in this clone. Run: bash .hackathon/bin/hk.sh init <yourname>"; }
valid_id(){ printf '%s' "$1" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$' && [ "$1" != id ] || die "hk: bad task id '$1' (letters, digits, . _ -)"; }
oneline(){ printf '%s' "$*" | tr '\r\n' '  '; }
cell(){ oneline "$*" | tr '|' '/'; }
stamp(){ date +%H:%M; }
setup_cfg(){ # local-only config: merge driver (absolute path; git runs it from the state checkout) + ignore
  local q x; q=$(printf '%s' "$SELF" | sed "s/'/'\\\\''/g")
  gm config merge.hkboard.name "hackathon board row merge"
  gm config merge.hkboard.driver "bash '$q' _mergeboard %O %A %B"
  gm check-ignore -q "$WT/" 2>/dev/null && return 0
  x=$(gm rev-parse --git-path info/exclude); case $x in /*) ;; *) x=$ROOT/$x;; esac
  mkdir -p "$(dirname "$x")"; echo "/.hackathon/state/" >> "$x"; }
seen_set(){ g rev-parse HEAD > "$H/.seen" 2>/dev/null || true; }

# ---- board (markdown table: | id | owner | status | ref |) ----
row(){ awk -F'|' -v id="$1" '{k=$2; gsub(/^[ \t]+|[ \t]+$/,"",k)} k==id {print; exit}' "$WT/BOARD.md"; }
field(){ printf '%s\n' "$1" | awk -F'|' -v n="$2" '{v=$n; gsub(/^[ \t]+|[ \t]+$/,"",v); print v}'; }
setrow(){ # id owner status ref   (empty = keep)
  HK_ID=$1 HK_O=$2 HK_S=$3 HK_R=$4 awk -F'|' -v OFS='|' '
    {k=$2; gsub(/^[ \t]+|[ \t]+$/,"",k)}
    k==ENVIRON["HK_ID"] && NF>=6 {
      if (ENVIRON["HK_O"]!="") $3=" " ENVIRON["HK_O"] " "
      if (ENVIRON["HK_S"]!="") $4=" " ENVIRON["HK_S"] " "
      if (ENVIRON["HK_R"]!="") $5=" " ENVIRON["HK_R"] " " }
    {print}' "$WT/BOARD.md" > "$WT/BOARD.md.tmp" && mv "$WT/BOARD.md.tmp" "$WT/BOARD.md"; }
open_tasks(){ awk -F'|' 'NF>=6 {k=$2; s=$4; gsub(/[ \t]/,"",k); gsub(/[ \t]/,"",s)
  if (k!="" && k!="id" && k !~ /^-+$/ && s!="done") print}' "$WT/BOARD.md"; }
news(){ # lines teammates added between $1 and $2 (own lines and finished rows filtered out)
  [ -n "$1" ] && g cat-file -e "$1^{commit}" 2>/dev/null || return 0
  g diff -U0 "$1" "$2" -- BOARD.md LOG.md DECISIONS.md 2>/dev/null | grep -E '^\+([^+]|$)' | sed 's/^+//' \
    | grep -v -e "^[0-9:]* @$ME " -e "| @$ME |" -e '| done |' -e '^[[:space:]]*$' || true; }

# ---- state branch sync ----
commit_stray(){ [ -n "$(g status --porcelain 2>/dev/null)" ] || return 0
  g add -A && g commit -qm "edit ($ME)" || die "hk: can't commit in $WT (is git user.name/email set?)"; }
state_pull(){ # 0 ok, 1 offline, 2 local pending commits conflict with remote
  commit_stray
  [ -n "$R" ] || return 0
  fetch || return 1
  gm rev-parse -q --verify "$RREF" >/dev/null || return 0
  g rebase -q "$RREF" >/dev/null 2>&1 && return 0
  g rebase --abort >/dev/null 2>&1; return 2; }
ahead(){ [ -n "$R" ] || { echo 0; return; }
  if gm rev-parse -q --verify "$RREF" >/dev/null; then g rev-list --count "$RREF..HEAD"; else g rev-list --count HEAD; fi; }
publish(){ # push local state commits; 0 pushed, 1 offline, 2 conflict
  [ -n "$R" ] || return 0
  local i rc
  for i in 1 2 3 4 5; do
    push1 && return 0
    state_pull; rc=$?; [ $rc -ne 0 ] && return $rc
  done; return 1; }
conflict_msg(){ echo "STATE CONFLICT: your unpushed board edits clash with a teammate's edit of the same row."
  echo "  Fix: cd .hackathon/state && git rebase $R/$BR (resolve BOARD.md, git rebase --continue), then hk.sh sync"; }
report(){ # $1 publish rc, $2 success text
  case $1 in
    0) echo "$2";;
    1) echo "$2 - NOT PUSHED (remote unreachable). Saved locally; hk.sh sync will retry."; exit 2;;
    *) echo "$2 - NOT PUSHED."; conflict_msg; exit 2;;
  esac; }
prep(){ # fresh state before a mutation; offline is fine (edit stays pending), conflict is not
  need; lock; state_pull; case $? in 2) conflict_msg; exit 1;; esac; }

case "$CMD" in
init)
  name=$(printf '%s' "${1:-}" | tr 'A-Z' 'a-z')
  printf '%s' "$name" | grep -Eq '^[a-z0-9][a-z0-9_-]*$' || die "usage: hk.sh init <name>   (letters, digits, _ -)"
  gm rev-parse -q --verify HEAD >/dev/null || die "hk: commit something first (the harness files are fine)."
  gm var GIT_COMMITTER_IDENT >/dev/null 2>&1 || die "hk: set git user.name and user.email first."
  lock; mkdir -p "$H"; printf '%s\n' "$name" > "$H/.me"; ME=$name
  hp=$(gm config core.hooksPath || true)
  if [ -z "$hp" ] || [ "$hp" = .githooks ]; then gm config core.hooksPath .githooks; hookmsg="pre-push check on main enabled"
  else hookmsg="core.hooksPath is '$hp' (left alone; pre-push check NOT enabled)"; fi
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
      if [ -f "$H/BOARD.md" ]; then cp "$H/BOARD.md" "$WT/BOARD.md"   # migrate a v1 board
      else printf '| id | owner | status | ref |\n|---|---|---|---|\n' > "$WT/BOARD.md"; fi
      if [ -f "$H/LOG.md" ]; then cp "$H/LOG.md" "$WT/LOG.md"; else : > "$WT/LOG.md"; fi
      if [ -f "$H/DECISIONS.md" ]; then cp "$H/DECISIONS.md" "$WT/DECISIONS.md"
      else echo "# Decisions (one line each, never re-argue)" > "$WT/DECISIONS.md"; fi
      printf 'BOARD.md merge=hkboard\nLOG.md merge=union\nDECISIONS.md merge=union\n' > "$WT/.gitattributes"
      g add -A && g commit -qm "hackathon state: init ($ME)" || die "hk: initial state commit failed"
      if [ -n "$R" ] && ! push1; then   # someone created it at the same moment: use theirs
        fetch && gm rev-parse -q --verify "$RREF" >/dev/null && g reset -q --hard "$RREF" \
          || echo "warning: couldn't push the new state branch; hk.sh sync will retry."
      fi
    fi
  fi
  seen_set
  echo "ok: you are @$ME. Board: .hackathon/state/BOARD.md (branch $BR${R:+ on $R}). $hookmsg." ;;

sync)
  if ! inited; then [ "${1:-}" = --hook ] && exit 0; need; fi
  lock; setup_cfg; state_pull; rc=$?
  case $rc in 1) echo "OFFLINE: can't reach '$R'; showing the last known board.";; 2) conflict_msg;; esac
  if [ $rc -eq 0 ] && [ "$(ahead)" -gt 0 ]; then publish && echo "pushed pending board/log updates" || echo "pending updates still not pushed"; fi
  n=$(news "$(cat "$H/.seen" 2>/dev/null || true)" HEAD); seen_set
  [ -n "$n" ] && { echo "NEW:"; echo "$n"; }
  t=$(open_tasks); echo "OPEN TASKS:"; echo "${t:-(none)}" ;;

peek) # runs on every prompt: report from the last background fetch, then start the next one
  inited && [ -n "$R" ] || exit 0
  seen=$(cat "$H/.seen" 2>/dev/null || true); r=$(gm rev-parse -q --verify "$RREF" || true)
  if [ -n "$r" ] && [ "$r" != "$seen" ]; then
    n=$(news "$seen" "$r"); echo "$r" > "$H/.seen"
    [ -n "$n" ] && { echo "TEAM UPDATES:"; echo "$n"; }
  fi
  last=$(cat "$H/.fetched" 2>/dev/null || echo 0); now=$(date +%s)
  if [ $((now - last)) -ge 20 ]; then
    echo "$now" > "$H/.fetched"
    nohup bash "$SELF" _bgfetch >/dev/null 2>&1 </dev/null &
  fi
  exit 0 ;;

_bgfetch) # fetch, and fast-forward the state checkout if nothing local is pending
  mkdir "$LOCK" 2>/dev/null || exit 0; echo $$ > "$LOCK/pid"; trap 'rm -rf "$LOCK"' EXIT
  fetch || exit 0
  [ -z "$(g status --porcelain 2>/dev/null)" ] && g merge -q --ff-only "$RREF" >/dev/null 2>&1
  exit 0 ;;

_mergeboard) # git merge driver: 3-way merge of BOARD.md by task row; only same-row edits conflict
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
  id=${1:-}; valid_id "$id"; need; lock
  for attempt in 1 2 3 4 5; do
    state_pull; rc=$?
    [ $rc = 1 ] && die "OFFLINE: can't reach '$R'. Claim NOT made (the remote is the lock); retry when online."
    [ $rc = 2 ] && { conflict_msg; exit 1; }
    r=$(row "$id"); [ -n "$r" ] || die "no task '$id' on the board (add it: hk.sh add $id <ref>)"
    owner=$(field "$r" 3); status=$(field "$r" 4)
    [ "$owner" = "@$ME" ] && { echo "ALREADY YOURS: $id"; exit 0; }
    [ "$status" = "done" ] && die "ALREADY DONE: $id"
    if [ "$owner" != "-" ] && [ -n "$owner" ]; then
      [ $attempt -gt 1 ] && die "LOST RACE: $owner claimed $id first. Pick another task."
      die "TAKEN by $owner"
    fi
    setrow "$id" "@$ME" doing ""; g commit -qam "claim $id ($ME)" || die "hk: commit failed"
    [ -n "$R" ] || { echo "CLAIMED $id (no remote: local only)"; exit 0; }
    push1 && { seen_set; echo "CLAIMED $id"; exit 0; }
    g reset -q --hard HEAD~1   # drop our claim, re-read the latest board, try again
  done
  die "claim NOT made: push kept failing. Run hk.sh sync and retry." ;;

release)
  id=${1:-}; valid_id "$id"; prep
  r=$(row "$id"); [ -n "$r" ] || die "no task '$id'"
  [ "$(field "$r" 3)" = "@$ME" ] || die "not yours: $id is owned by $(field "$r" 3)"
  setrow "$id" - todo ""; echo "$(stamp) @$ME RELEASED $id" >> "$WT/LOG.md"
  g commit -qam "release $id ($ME)" || die "hk: commit failed"; publish; report $? "RELEASED $id" ;;

done)
  id=${1:-}; valid_id "$id"; ref=$(cell "${2:--}"); prep
  r=$(row "$id"); [ -n "$r" ] || die "no task '$id'"
  owner=$(field "$r" 3)
  [ "$owner" = "@$ME" ] || [ "$owner" = "-" ] || die "not yours: $id is owned by $owner"
  setrow "$id" "@$ME" "done" "$ref"; echo "$(stamp) @$ME DONE $id -> $ref" >> "$WT/LOG.md"
  g commit -qam "done $id ($ME)" || die "hk: commit failed"; publish; report $? "DONE $id" ;;

add)
  id=${1:-}; valid_id "$id"; ref=$(cell "${2:--}"); prep
  [ -z "$(row "$id")" ] || die "task '$id' already exists"
  [ -z "$(tail -c1 "$WT/BOARD.md")" ] || echo >> "$WT/BOARD.md"
  echo "| $id | - | todo | $ref |" >> "$WT/BOARD.md"
  g commit -qam "add $id ($ME)" || die "hk: commit failed"; publish; report $? "ADDED $id" ;;

log|decide)
  [ $# -gt 0 ] || die "usage: hk.sh $CMD <text>"; prep
  f=LOG.md; [ "$CMD" = decide ] && f=DECISIONS.md
  echo "$(stamp) @$ME $(oneline "$*")" >> "$WT/$f"
  g commit -qam "$CMD ($ME)" || die "hk: commit failed"; publish; report $? "saved to $f" ;;

board) need; cat "$WT/BOARD.md" ;;

*) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
