#!/usr/bin/env bash
# Prints time left; injected into context so the agent scopes to the clock. Near-zero tokens.
f=.hackathon/deadline; [ -f "$f" ] || exit 0
now=$(date +%s); d=$(cat $f); end=$(date -d "$d" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M" "$d" +%s 2>/dev/null) || exit 0
left=$(( (end-now)/60 ))
if [ "$1" = "--quiet-unless-late" ]; then [ $left -gt 240 ] && exit 0; fi
if   [ $left -le 0 ];   then echo "HACKATHON: DEADLINE PASSED. Only submit."
elif [ $left -le 60 ];  then echo "HACKATHON: ${left}m left. FEATURE FREEZE. Only demo-path bugs, README, demo video, submission."
elif [ $left -le 240 ]; then echo "HACKATHON: ${left}m left. Finish vertical slice, then polish. Cut anything off the demo path."
else echo "HACKATHON: $((left/60))h$((left%60))m left."; fi
