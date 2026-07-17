#!/usr/bin/env bash
set -euo pipefail

# =========================================================================
# uninstall.sh — Speak (TTS) Tool uninstaller for OpenCode
# Removes tool files; shared venv and user data are left untouched.
# =========================================================================

TOOLS_DIR="${HOME}/.config/opencode/tools"
VENV_DIR="${TOOLS_DIR}/venv"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }

echo ""
echo "========================================"
echo "  OpenCode Speak (TTS) Tool Uninstaller"
echo "========================================"
echo ""

log "Removing speak tool files..."
rm -f "$TOOLS_DIR/speak.py" "$TOOLS_DIR/speak.ts" "$TOOLS_DIR/speak_config.json"
log "Tool files removed."

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  UNINSTALL COMPLETE${NC}"
echo ""
echo "  Note: shared venv at $VENV_DIR was NOT removed"
echo "  (other tools may use it)."
echo ""
echo "  To remove the shared venv manually:"
echo "    rm -rf $VENV_DIR"
echo -e "${GREEN}============================================${NC}"
