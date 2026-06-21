#!/bin/bash
# Claude Brain Setup Script for macOS/Linux
# Run once on any new machine: bash <(curl -s https://raw.githubusercontent.com/salaumusst-oss/claude-brain/main/setup/setup-mac.sh)

MACHINE_NAME="${1:-$(hostname -s)}"
CLONE_DIR="${2:-$HOME/claude-brain}"

echo ""
echo "🧠 Claude Brain Setup"
echo "═══════════════════════════════════"

# 1. Clone or pull
if [ ! -d "$CLONE_DIR/.git" ]; then
    echo "[1/4] Cloning brain repo..."
    git clone https://github.com/salaumusst-oss/claude-brain.git "$CLONE_DIR" || { echo "Clone failed."; exit 1; }
else
    echo "[1/4] Repo exists. Pulling latest..."
    git -C "$CLONE_DIR" pull
fi

# 2. Git identity
echo "[2/4] Configuring git identity..."
git -C "$CLONE_DIR" config user.email "salaumusst@gmail.com"
git -C "$CLONE_DIR" config user.name "$MACHINE_NAME"

# 3. Machine config
echo "[3/4] Writing machine config..."
cat > "$CLONE_DIR/app/config.json" <<EOF
{
  "machineName": "$MACHINE_NAME",
  "brainDir": "$CLONE_DIR",
  "autoSyncInterval": 60
}
EOF

# 4. Claude Code settings
echo "[4/4] Wiring Claude Code auto-sync hook..."
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
SYNC_CMD="bash $CLONE_DIR/sync.sh auto-sync"

if [ -f "$CLAUDE_SETTINGS" ]; then
    # Merge hook into existing settings using python (available on mac by default)
    python3 - <<PYEOF
import json, os

settings_path = "$CLAUDE_SETTINGS"
with open(settings_path) as f:
    s = json.load(f)

hook = {"matcher": "", "hooks": [{"type": "command", "command": "$SYNC_CMD"}]}
s.setdefault("hooks", {}).setdefault("Stop", [])
if not any(h.get("hooks", [{}])[0].get("command","").endswith("sync.sh auto-sync") for h in s["hooks"]["Stop"]):
    s["hooks"]["Stop"].append(hook)

with open(settings_path, "w") as f:
    json.dump(s, f, indent=2)
print("Settings updated.")
PYEOF
else
    mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
    cat > "$CLAUDE_SETTINGS" <<EOF
{
  "hooks": {
    "Stop": [{"matcher": "", "hooks": [{"type": "command", "command": "$SYNC_CMD"}]}]
  }
}
EOF
fi

# 5. macOS Launch Agent (auto-start on login)
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.claudebrain.tray.plist"
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Installing macOS launch agent..."
    cat > "$LAUNCH_AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.claudebrain.sync</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$CLONE_DIR/sync.sh</string>
        <string>scheduled</string>
    </array>
    <key>StartInterval</key><integer>60</integer>
    <key>RunAtLoad</key><true/>
    <key>StandardOutPath</key><string>$CLONE_DIR/logs/sync.log</string>
    <key>StandardErrorPath</key><string>$CLONE_DIR/logs/sync-err.log</string>
</dict>
</plist>
EOF
    mkdir -p "$CLONE_DIR/logs"
    launchctl load "$LAUNCH_AGENT" 2>/dev/null
    echo "  Launch agent installed."
fi

echo ""
echo "✓ Setup complete!"
echo "  Machine name : $MACHINE_NAME"
echo "  Brain dir    : $CLONE_DIR"
echo ""
echo "Open dashboard:"
echo "  bash $CLONE_DIR/app/brain-mac.sh"
