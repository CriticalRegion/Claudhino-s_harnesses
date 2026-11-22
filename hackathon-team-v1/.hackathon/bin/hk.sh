#!/usr/bin/env bash
# hk.sh - git-backed team/agent coordination. init <name> | sync | peek | claim <id> | done <id> <ref> | log <text>
cd "$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
H=.hackathon; B=$H/BOARD.md; L=$H/LOG.md; FILES="$B $L $H/DECISIONS.md"
ME=$(cat $H/.me 2>/dev/null || echo "${HK_ME:-}")
remote(){ git remote | grep -q .; }
upstream(){ git rev-parse --verify -q '@{u}' || git rev-parse --verify -q "origin/$(git rev-parse --abbrev-ref HEAD)"; }
need_me(){ [ -n "$ME" ] || { echo "Run: bash $H/bin/hk.sh init <yourname>"; exit 1; }; }
pull(){ remote && git pull --rebase --autostash -q 2>/dev/null; }
push(){ remote || return 0; git push -q 2>/dev/null || { pull && git push -q; }; }
news(){ # added lines in coordination files between $1..$2, excluding my own
  git diff -U0 "$1" "$2" -- $FILES 2>/dev/null | grep -E '^\+[^+]' | sed 's/^+//' \
    | grep -v -e "^[0-9:]* @$ME " -e "| @$ME |" ; true; }
now(){ date +%s; }

case "$1" in
init) [ -n "$2" ] || { echo "usage: init <name>"; exit 1; }
  echo "$2" | tr 'A-Z' 'a-z' > $H/.me; git config core.hooksPath .githooks
  git rev-parse HEAD > $H/.seen 2>/dev/null; echo "ok: you are @$(cat $H/.me); pre-push hook enabled" ;;

peek) remote || exit 0; t=$H/.fetched; last=$(cat $t 2>/dev/null || echo 0)
  if [ $(( $(now) - last )) -gt 20 ]; then echo $(now) > $t; T=""; command -v timeout >/dev/null && T="timeout 8"; $T git fetch -q 2>/dev/null; fi
  u=$(upstream) || exit 0; s=$(cat $H/.seen 2>/dev/null || git rev-parse HEAD)
  [ "$s" = "$u" ] && exit 0
  n=$(news "$s" "$u"); echo "$u" > $H/.seen
  [ -n "$n" ] && { echo "TEAM UPDATES (use /sync to pull):"; echo "$n"; } ; exit 0 ;;

sync) if remote; then git fetch -q 2>/dev/null; pull || { echo "SYNC CONFLICT: fix, then git rebase --continue"; exit 1; }; fi
  s=$(cat $H/.seen 2>/dev/null); h=$(git rev-parse HEAD); n=""
  [ -n "$s" ] && [ "$s" != "$h" ] && n=$(news "$s" "$h"); echo "$h" > $H/.seen
  [ -n "$n" ] && { echo "NEW:"; echo "$n"; }
  echo "OPEN TASKS:"; grep -E '^\|' $B | grep -v -E '^\|( id |-)' | grep -vi '| done |' ; exit 0 ;;

claim) need_me; id=$2; pull
  l=$(grep -n -E "^\| $id \|" $B | head -1 | cut -d: -f1); [ -n "$l" ] || { echo "no task '$id' on board"; exit 1; }
  owner=$(sed -n "${l}p" $B | awk -F'|' '{gsub(/ /,"",$3);print $3}')
  [ "$owner" = "-" ] || [ "$owner" = "@$ME" ] || { echo "TAKEN by $owner"; exit 1; }
  awk -F'|' -v OFS='|' -v l=$l -v me="@$ME" 'NR==l{$3=" "me" ";$4=" doing "}1' $B > $B.tmp && mv $B.tmp $B
  git commit -q -m "claim $id ($ME)" -- $B
  if remote && ! git push -q 2>/dev/null; then
    if pull; then git push -q || exit 1
    else git rebase --abort 2>/dev/null; git reset -q --mixed HEAD~1; git checkout -q -- $B; pull
      echo "LOST RACE: $id was claimed by someone else"; exit 1; fi; fi
  echo "CLAIMED $id" ;;

done) need_me; id=$2; ref=${3:--}; pull
  l=$(grep -n -E "^\| $id \|" $B | head -1 | cut -d: -f1); [ -n "$l" ] || { echo "no task '$id'"; exit 1; }
  awk -F'|' -v OFS='|' -v l=$l -v r="$ref" 'NR==l{$4=" done ";$5=" "r" "}1' $B > $B.tmp && mv $B.tmp $B
  echo "$(date +%H:%M) @$ME DONE $id -> $ref" >> $L
  git add $B $L; git commit -q -m "done $id ($ME)" -- $B $L; push; echo "DONE $id" ;;

log) need_me; shift; echo "$(date +%H:%M) @$ME $*" >> $L
  git add $L; git commit -q -m "log ($ME)" -- $L; push; echo "logged" ;;

*) echo "usage: hk.sh init <name> | sync | peek | claim <id> | done <id> <ref> | log <text>"; exit 1 ;;
esac
