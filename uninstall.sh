#!/bin/bash

# Synapse AI — Uninstall Script
# Usage: curl -sSL https://raw.githubusercontent.com/Chrisl154/synapse-ai-cpm/master/uninstall.sh | bash
#    or: bash uninstall.sh [--keep-data]

set -e

# ---------------------------------------------------------------------------
# Detect OS
# ---------------------------------------------------------------------------
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        OS="windows"
    else
        OS="unknown"
    fi
}

detect_os

# Installation directory — must match setup.sh
if [[ "$OS" == "macos" ]]; then
    INSTALL_DIR="$HOME/Library/Application Support/SynapseAI"
else
    INSTALL_DIR="$HOME/.local/share/SynapseAI"
fi

KEEP_DATA=false
for arg in "$@"; do
    [[ "$arg" == "--keep-data" ]] && KEEP_DATA=true
done

echo ""
echo "========================================================"
echo "   Synapse AI — Uninstall"
echo "========================================================"
echo ""

# ---------------------------------------------------------------------------
# If the synapse CLI is available, delegate to it (handles everything)
# ---------------------------------------------------------------------------
SYNAPSE_BIN=""
if command -v synapse &>/dev/null; then
    SYNAPSE_BIN=$(command -v synapse)
elif [ -x "$INSTALL_DIR/bin/synapse" ]; then
    SYNAPSE_BIN="$INSTALL_DIR/bin/synapse"
fi

if [ -n "$SYNAPSE_BIN" ]; then
    echo "Found Synapse CLI at: $SYNAPSE_BIN"
    echo "Delegating to: synapse uninstall"
    echo ""
    if $KEEP_DATA; then
        "$SYNAPSE_BIN" uninstall --keep-data
    else
        "$SYNAPSE_BIN" uninstall
    fi
    exit $?
fi

# ---------------------------------------------------------------------------
# Manual uninstall fallback (when synapse CLI is not available)
# ---------------------------------------------------------------------------
echo "The 'synapse' command was not found. Performing manual uninstall..."
echo ""

# Confirm
read -r -p "This will PERMANENTLY remove Synapse AI. Type 'yes' to confirm: " _answer
if [[ "$_answer" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

echo ""

# Stop running services via PID files
RUN_DIR="$INSTALL_DIR/run"
DATA_PID_DIR="$HOME/.synapse"
for pidFile in "$RUN_DIR/backend.pid" "$RUN_DIR/frontend.pid" \
               "$DATA_PID_DIR/backend.pid" "$DATA_PID_DIR/frontend.pid"; do
    if [ -f "$pidFile" ]; then
        pid=$(cat "$pidFile" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null && echo "  Stopped process $pid ($(basename $pidFile))" || true
        fi
        rm -f "$pidFile"
    fi
done

# Also try by port (best effort)
for port in 8765 3000; do
    if command -v lsof &>/dev/null; then
        pid=$(lsof -ti :"$port" 2>/dev/null || true)
        if [ -n "$pid" ]; then
            kill "$pid" 2>/dev/null && echo "  Stopped process on port $port" || true
        fi
    fi
done

# Remove macOS LaunchAgent
if [[ "$OS" == "macos" ]]; then
    plist="$HOME/Library/LaunchAgents/com.synapse-ai.server.plist"
    if [ -f "$plist" ]; then
        launchctl unload "$plist" 2>/dev/null || true
        rm -f "$plist"
        echo "  Removed macOS LaunchAgent."
    fi
fi

# Remove Linux systemd user service
if [[ "$OS" == "linux" ]]; then
    service_file="$HOME/.config/systemd/user/synapse-ai.service"
    if [ -f "$service_file" ]; then
        systemctl --user disable synapse-ai.service 2>/dev/null || true
        rm -f "$service_file"
        systemctl --user daemon-reload 2>/dev/null || true
        echo "  Removed systemd user service."
    fi
fi

# Remove data directory (unless --keep-data)
if ! $KEEP_DATA; then
    for data_dir in "$HOME/.synapse" "$HOME/.local/share/SynapseAI/data" \
                    "$HOME/Library/Application Support/SynapseAI/data"; do
        if [ -d "$data_dir" ]; then
            echo "  Removing data: $data_dir"
            rm -rf "$data_dir"
        fi
    done
fi

# Remove installation directory
if [ -d "$INSTALL_DIR" ]; then
    echo ""
    echo "Removing installation directory: $INSTALL_DIR"
    # Remove large subdirs first
    rm -rf "$INSTALL_DIR/backend/venv" 2>/dev/null || true
    rm -rf "$INSTALL_DIR/frontend/node_modules" 2>/dev/null || true
    rm -rf "$INSTALL_DIR"
    echo "  Removed."
else
    echo "Installation directory not found: $INSTALL_DIR"
    echo "  (May already be removed or was installed elsewhere.)"
fi

# Clean PATH entries from shell rc files
BIN_DIR="$INSTALL_DIR/bin"
echo ""
echo "Cleaning shell profile files..."
for rc_file in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile"; do
    if [ -f "$rc_file" ]; then
        if grep -qE "SynapseAI|Synapse AI|synapse-ai" "$rc_file" 2>/dev/null; then
            grep -vE "SynapseAI|Synapse AI|synapse-ai" "$rc_file" > "$rc_file.synapse_bak" \
                && mv "$rc_file.synapse_bak" "$rc_file" \
                && echo "  Cleaned PATH from $rc_file" \
                || rm -f "$rc_file.synapse_bak"
        fi
    fi
done

echo ""
echo "========================================================"
echo -e "\033[92m   Synapse AI has been uninstalled.\033[0m"
if $KEEP_DATA; then
    echo "   Your data directory was preserved."
fi
echo ""
echo "   Open a new terminal to apply PATH changes."
echo "========================================================"
echo ""
