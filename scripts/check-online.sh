#!/bin/bash
# Check if other machine is online (heartbeat < 2 min old)
BRAIN_DIR="${1:-$HOME/claude-brain}"
MY_MACHINE=$(hostname -s)
THRESHOLD=120

git -C "$BRAIN_DIR" pull 2>/dev/null

NOW=$(date +%s)

for beat in "$BRAIN_DIR/heartbeat/"*.json; do
    [ -f "$beat" ] || continue
    NAME=$(basename "$beat" .json)
    [ "$NAME" = "$MY_MACHINE" ] && continue

    EPOCH=$(python3 -c "import json; d=json.load(open('$beat')); print(d['epoch'])" 2>/dev/null)
    [ -z "$EPOCH" ] && continue

    AGE=$(( NOW - EPOCH ))
    if [ "$AGE" -lt "$THRESHOLD" ]; then
        echo "online:$NAME"
        exit 0
    fi
done

echo "offline"
