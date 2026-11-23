#!/usr/bin/env bash
# Prints time left (~20 tokens) so the agent scopes to the clock. Reads .hackathon/deadline
# (local time, YYYY-MM-DDTHH:MM). --quiet-unless-late: print only in the last 4 hours.
# --minutes: print just the minutes left (nothing if no deadline is set); used by hk.sh.
root=$(cd "$(dirname "$0")/../.." && pwd)
f=$root/.hackathon/deadline; [ -f "$f" ] || exit 0
d=$(head -n1 "$f" | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
case $d in ''|*YYYY*) exit 0;; esac   # placeholder: not set yet
end=$(date -d "$d" +%s 2>/dev/null) || end=
if [ -z "$end" ]; then   # BSD/macOS date
  # BSD date fills fields missing from the format with the current time, so give it the seconds
  for try in "%Y-%m-%dT%H:%M:%S|$d:00" "%Y-%m-%dT%H:%M:%S|$d" "%Y-%m-%d %H:%M:%S|$d:00"; do
    end=$(date -j -f "${try%%|*}" "${try#*|}" +%s 2>/dev/null) && break; end=
  done
fi
if [ -z "$end" ]; then
  [ "${1:-}" = --quiet-unless-late ] || [ "${1:-}" = --minutes ] || echo "HACKATHON: can't read .hackathon/deadline ('$d'). Use local time like 2026-11-23T14:00."
  exit 0
fi
left=$(( (end - $(date +%s)) / 60 ))
[ "${1:-}" = --minutes ] && { echo "$left"; exit 0; }
[ "${1:-}" = --quiet-unless-late ] && [ $left -gt 240 ] && exit 0
if   [ $left -le 0 ];   then echo "HACKATHON: DEADLINE PASSED. Only submit."
elif [ $left -le 60 ];  then echo "HACKATHON: ${left}m left. FEATURE FREEZE. Only demo-path bugs, README, demo video, submission."
elif [ $left -le 240 ]; then echo "HACKATHON: $((left/60))h$((left%60))m left. Finish the vertical slice, then polish. Cut anything off the demo path."
else echo "HACKATHON: $((left/60))h$((left%60))m left."; fi
