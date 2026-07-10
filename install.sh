#!/usr/bin/env bash
# One-line installer for the Claude Code statusline.
#   curl -fsSL https://raw.githubusercontent.com/sergekruf/claude-statusline/main/install.sh | bash
set -euo pipefail

RAW_BASE="https://raw.githubusercontent.com/sergekruf/claude-statusline/main"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DEST="$CLAUDE_DIR/statusline-command.sh"
SETTINGS="$CLAUDE_DIR/settings.json"

echo "→ Installing Claude Code statusline into $DEST"
mkdir -p "$CLAUDE_DIR"

# --- dependencies ---
command -v jq  >/dev/null || { echo "✗ 'jq' is required (apt install jq / brew install jq)"; exit 1; }
command -v bc  >/dev/null || echo "⚠ optional 'bc' missing — cost segment will be hidden until installed"
command -v git >/dev/null || echo "⚠ optional 'git' missing — branch segment will show 'no-git'"

# --- download the script ---
curl -fsSL "$RAW_BASE/statusline-command.sh" -o "$DEST"
chmod +x "$DEST"
echo "✓ script installed"

# --- wire it into settings.json ---
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
tmp="$(mktemp)"
jq --arg cmd "bash $DEST" '.statusLine = {type:"command", command:$cmd}' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
echo "✓ settings.json updated (statusLine → bash $DEST)"

echo "Done. The panel re-renders on the next Claude Code turn — no restart needed."
