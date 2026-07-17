#!/usr/bin/env bash
set -euo pipefail

# =========================================================================
# install.sh — Speak (TTS) Tool installer for OpenCode
# Installs speak.py / speak.ts into ~/.config/opencode/tools/ with shared venv.
# =========================================================================

OPENCODE_DIR="${HOME}/.config/opencode"
TOOLS_DIR="${OPENCODE_DIR}/tools"
VENV_DIR="${TOOLS_DIR}/venv"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()  { echo -e "${RED}[ERR]${NC}   $*"; }

# -------------------------------------------------------------------
# Detect existing python3
# -------------------------------------------------------------------
find_system_python() {
    for py in python3 python; do
        if command -v "$py" &>/dev/null; then
            echo "$py"
            return
        fi
    done
    err "No python3 found on the system. Install python3 first."
    exit 1
}

# -------------------------------------------------------------------
# Ensure python3-venv is available (required for creating venv)
# -------------------------------------------------------------------
ensure_venv_module() {
    local py="$1"

    if "$py" -c "import ensurepip" 2>/dev/null; then
        return 0
    fi

    local py_version
    py_version="$("$py" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "")"

    warn "python3-venv (ensurepip) not installed."

    if command -v apt-get &>/dev/null; then
        log "Installing python${py_version}-venv via apt-get (may require sudo password)..."
        sudo -S apt-get update -qq
        sudo -S apt-get install -y -qq "python${py_version}-venv" python3-venv
    elif command -v dnf &>/dev/null; then
        log "Installing python${py_version}-venv via dnf..."
        sudo -S dnf install -y "python${py_version}-venv"
    elif command -v yum &>/dev/null; then
        log "Installing python${py_version}-venv via yum..."
        sudo -S yum install -y "python${py_version}-venv"
    elif command -v pacman &>/dev/null; then
        log "Installing python via pacman..."
        sudo -S pacman -S --noconfirm python
    else
        err "Cannot install python3-venv automatically — unknown package manager."
        err "Please install python3-venv manually and re-run this script."
        exit 1
    fi

    if ! "$py" -c "import ensurepip" 2>/dev/null; then
        err "python3-venv installation failed."
        exit 1
    fi
    log "python3-venv installed."
}

# -------------------------------------------------------------------
# Interactive: ask for TTS API config
# -------------------------------------------------------------------
ask_tts_config() {
    echo "" >&2
    echo -e "${YELLOW}════════════════════════════════════════════════${NC}" >&2
    echo -e "${YELLOW}  Configure TTS API (OpenAI-compatible)${NC}" >&2
    echo -e "${YELLOW}════════════════════════════════════════════════${NC}" >&2
    echo "" >&2

    echo -e "  ${CYAN}Example: https://routerai.ru/api/v1${NC}" >&2
    read -r -p "  Base URL: " TTS_BASE_URL
    TTS_BASE_URL="${TTS_BASE_URL:-https://routerai.ru/api/v1}"

    read -r -p "  API Key: " TTS_API_KEY
    if [ -z "$TTS_API_KEY" ]; then
        warn "No API key provided. You can set it later in the config file."
        TTS_API_KEY=""
    fi

    echo -e "  ${CYAN}Available models: x-ai/grok-voice-tts-1.0${NC}" >&2
    read -r -p "  Model ID [x-ai/grok-voice-tts-1.0]: " TTS_MODEL
    TTS_MODEL="${TTS_MODEL:-x-ai/grok-voice-tts-1.0}"

    echo -e "  ${CYAN}Available voices: eve, ara, rex, sal, leo${NC}" >&2
    read -r -p "  Voice [eve]: " TTS_VOICE
    TTS_VOICE="${TTS_VOICE:-eve}"

    echo "" >&2
    log "TTS config:"
    log "  Base URL: $TTS_BASE_URL"
    log "  Model:    $TTS_MODEL"
    log "  Voice:    $TTS_VOICE"
    if [ -n "$TTS_API_KEY" ]; then
        log "  API Key:  ****"
    else
        warn "  API Key:  (not set)"
    fi
}

# -------------------------------------------------------------------
# Check if required pip packages are installed in given python
# -------------------------------------------------------------------
check_packages() {
    local py="$1"
    "$py" -c "import openai" 2>/dev/null
}

# -------------------------------------------------------------------
# MAIN
# -------------------------------------------------------------------
main() {
    echo ""
    echo "========================================"
    echo "  OpenCode Speak (TTS) Tool Installer"
    echo "========================================"
    echo ""

    log "Detecting system python..."
    SYSTEM_PYTHON="$(find_system_python)"
    log "System python: $SYSTEM_PYTHON"

    ask_tts_config

    mkdir -p "$TOOLS_DIR"

    # --- Decide whether we need a venv ---
    NEED_VENV=false

    if [ -f "$VENV_DIR/bin/python3" ] || [ -f "$VENV_DIR/bin/python" ]; then
        if [ -f "$VENV_DIR/bin/python3" ]; then
            VENV_PYTHON="$VENV_DIR/bin/python3"
        else
            VENV_PYTHON="$VENV_DIR/bin/python"
        fi
        log "Existing venv found at $VENV_DIR"
        if check_packages "$VENV_PYTHON"; then
            log "Required packages already installed in venv."
        else
            log "Installing/updating required packages in existing venv..."
            "$VENV_PYTHON" -m pip install --upgrade pip -q
            "$VENV_PYTHON" -m pip install openai -q
        fi
    elif check_packages "$SYSTEM_PYTHON"; then
        log "Required packages found in system python."
        VENV_PYTHON="$SYSTEM_PYTHON"
    else
        NEED_VENV=true
        warn "Required packages not found. Creating venv..."
    fi

    # --- Create venv if needed ---
    if [ "$NEED_VENV" = true ]; then
        log "Creating venv at: $VENV_DIR"

        if "$SYSTEM_PYTHON" -c "import ensurepip" 2>/dev/null; then
            "$SYSTEM_PYTHON" -m venv "$VENV_DIR"
        elif "$SYSTEM_PYTHON" -m venv --without-pip "$VENV_DIR" 2>/dev/null; then
            log "ensurepip not available — bootstrapping pip via get-pip.py..."
            local GET_PIP
            GET_PIP="$(mktemp /tmp/get-pip.XXXXXX.py)"
            if curl -fsSL --retry 3 https://bootstrap.pypa.io/get-pip.py -o "$GET_PIP"; then
                "$VENV_DIR/bin/python3" "$GET_PIP" --no-setuptools --no-wheel -q
                rm -f "$GET_PIP"
            else
                rm -f "$GET_PIP"
                warn "Cannot download get-pip.py. Trying system package..."
                ensure_venv_module "$SYSTEM_PYTHON"
                rm -rf "$VENV_DIR"
                "$SYSTEM_PYTHON" -m venv "$VENV_DIR"
            fi
        else
            warn "venv creation failed outright. Trying system package..."
            ensure_venv_module "$SYSTEM_PYTHON"
            rm -rf "$VENV_DIR"
            "$SYSTEM_PYTHON" -m venv "$VENV_DIR"
        fi

        if [ -f "$VENV_DIR/bin/python3" ]; then
            VENV_PYTHON="$VENV_DIR/bin/python3"
        elif [ -f "$VENV_DIR/bin/python" ]; then
            VENV_PYTHON="$VENV_DIR/bin/python"
        else
            err "Venv created but python not found inside it."
            exit 1
        fi

        log "Upgrading pip..."
        "$VENV_PYTHON" -m pip install --upgrade pip -q

        log "Installing openai..."
        "$VENV_PYTHON" -m pip install openai -q
    fi

    # --- Verify installation ---
    log "Verifying installation..."
    if ! "$VENV_PYTHON" -c "import openai; print('openai:', openai.__version__)" 2>/dev/null; then
        err "openai package verification failed."
        exit 1
    fi
    log "openai: OK"

    # --- Copy tool files ---
    log "Copying tool files to $TOOLS_DIR ..."
    cp -v "$SCRIPT_DIR/speak.py" "$TOOLS_DIR/speak.py"
    cp -v "$SCRIPT_DIR/speak.ts" "$TOOLS_DIR/speak.ts"

    # --- Write config ---
    log "Writing config..."
    cat > "$TOOLS_DIR/speak_config.json" <<EOF
{
  "base_url": "$TTS_BASE_URL",
  "api_key": "$TTS_API_KEY",
  "model": "$TTS_MODEL",
  "voice": "$TTS_VOICE"
}
EOF
    log "Config written to $TOOLS_DIR/speak_config.json"
    log "Venv python: $VENV_PYTHON"

    echo ""
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  ✅  INSTALLATION COMPLETE!${NC}"
    echo ""
    echo -e "  ${GREEN}Available tools:${NC}"
    echo "    speak  — Convert text to speech and play it to the user"
    echo ""
    echo -e "  ${GREEN}Config:${NC} $TOOLS_DIR/speak_config.json"
    echo -e "${GREEN}============================================${NC}"
}

main "$@"
