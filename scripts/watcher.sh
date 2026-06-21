#!/bin/bash
# Watcher — runs on Mac, picks up tasks dispatched from PC
# Start: bash ~/claude-brain/scripts/watcher.sh

BRAIN_DIR="${1:-$HOME/claude-brain}"
MY_MACHINE=$(hostname -s)
POLL_INTERVAL=15

log() { echo "[$(date '+%H:%M:%S')] $1"; }

notify() {
    if command -v osascript &>/dev/null; then
        osascript -e "display notification \"$2\" with title \"$1\""
    fi
}

# Write heartbeat
write_heartbeat() {
    EPOCH=$(date +%s)
    cat > "$BRAIN_DIR/heartbeat/$MY_MACHINE.json" <<EOF
{
  "machine": "$MY_MACHINE",
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')",
  "epoch": $EPOCH,
  "platform": "mac"
}
EOF
    git -C "$BRAIN_DIR" add "heartbeat/$MY_MACHINE.json" 2>/dev/null
    git -C "$BRAIN_DIR" commit -m "heartbeat: $MY_MACHINE" 2>/dev/null
    git -C "$BRAIN_DIR" push origin main 2>/dev/null
}

process_task() {
    local TASK_FILE="$1"
    local TASK_NAME=$(basename "$TASK_FILE")
    local CONTENT=$(cat "$TASK_FILE")

    # Parse
    local TASK=$(echo "$CONTENT" | grep "^task:" | sed 's/task: //')
    local FROM=$(echo "$CONTENT" | grep "^from:" | sed 's/from: //')
    local ID=$(echo "$CONTENT" | grep "^id:" | sed 's/id: //')

    log "Picking up task from $FROM: $TASK"
    notify "Claude Brain — Task Received" "From $FROM: $TASK"

    # Mark active
    local ACTIVE_FILE="${TASK_FILE/-pending.md/-active.md}"
    mv "$TASK_FILE" "$ACTIVE_FILE"
    git -C "$BRAIN_DIR" add -A 2>/dev/null
    git -C "$BRAIN_DIR" commit -m "task: $MY_MACHINE picked up $ID" 2>/dev/null
    git -C "$BRAIN_DIR" push origin main 2>/dev/null

    # Run Claude
    log "Running Claude on task $ID..."
    local CLAUDE_PROMPT="You are the REMOTE Claude instance in a two-machine collaboration.
The LOCAL instance on $FROM dispatched this task to you.

$CONTENT

Complete your assigned work. When done write your FULL results after a line that says '## RESULT'."

    local RESULT=""
    if command -v claude &>/dev/null; then
        RESULT=$(claude --print "$CLAUDE_PROMPT" 2>&1)
    else
        RESULT="WAITING_FOR_MANUAL: claude CLI not found. Install with: npm install -g @anthropic-ai/claude-code"
        log "WARNING: claude CLI not found."
        notify "Claude Brain — Action Needed" "Install Claude CLI: npm install -g @anthropic-ai/claude-code"
    fi

    # Write done file
    local DONE_FILE="${ACTIVE_FILE/-active.md/-done.md}"
    printf "%s\n\n## RESULT\n\n%s" "$CONTENT" "$RESULT" > "$DONE_FILE"
    rm -f "$ACTIVE_FILE"

    # Sync back
    git -C "$BRAIN_DIR" add -A 2>/dev/null
    git -C "$BRAIN_DIR" commit -m "task: $MY_MACHINE completed $ID" 2>/dev/null
    git -C "$BRAIN_DIR" push origin main 2>/dev/null

    log "Task $ID complete. Synced back."
    notify "Claude Brain — Task Done" "Completed: $TASK"
}

log "Watcher started on $MY_MACHINE. Polling every ${POLL_INTERVAL}s..."

while true; do
    # Pull latest
    git -C "$BRAIN_DIR" pull 2>/dev/null

    # Find pending tasks for this machine
    for task in "$BRAIN_DIR/tasks/"*"-$MY_MACHINE-pending.md" 2>/dev/null; do
        [ -f "$task" ] && process_task "$task"
    done

    # Heartbeat
    write_heartbeat

    sleep $POLL_INTERVAL
done
