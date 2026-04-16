#!/bin/bash

# Synapse AI — Uninstall Script
# Usage: curl -sSL https://raw.githubusercontent.com/Chrisl154/synapse-ai-cpm/master/uninstall.sh | bash
#    or: bash uninstall.sh [--keep-data]

# ---------------------------------------------------------------------------
# Detect OS
# ---------------------------------------------------------------------------
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
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
# Confirm — always read from /dev/tty so this works inside curl | bash
# ---------------------------------------------------------------------------
echo "This will PERMANENTLY remove Synapse AI and all its files."
if $KEEP_DATA; then
    echo "(Your data in ~/.synapse will be preserved.)"
fi
echo ""
read -r -p "Type 'yes' to confirm: " _answer < /dev/tty
echo ""

if [[ "$_answer" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

# ---------------------------------------------------------------------------
# 1. Stop running services via PID files
# ---------------------------------------------------------------------------
echo "Stopping services..."
_DATA_DIRS=("$HOME/.synapse" "$HOME/.synapse/data" "$INSTALL_DIR/run")
for _dir in "${_DATA_DIRS[@]}"; do
    for _pid_file in "$_dir/backend.pid" "$_dir/frontend.pid"; do
        if [ -f "$_pid_file" ]; then
            _pid=$(cat "$_pid_file" 2>/dev/null)
            if [ -n "$_pid" ] && kill -0 "$_pid" 2>/dev/null; then
                kill "$_pid" 2>/dev/null && echo "  Stopped PID $_pid ($(basename "$_pid_file"))" || true
            fi
            rm -f "$_pid_file"
        fi
    done
done

# Best-effort kill by port
for _port in 8765 3000; do
    if command -v lsof &>/dev/null; then
        _pid=$(lsof -ti :"$_port" 2>/dev/null || true)
        if [ -n "$_pid" ]; then
            kill "$_pid" 2>/dev/null && echo "  Stopped process on port $_port" || true
        fi
    fi
done

# ---------------------------------------------------------------------------
# 2. Remove startup entries
# ---------------------------------------------------------------------------
if [[ "$OS" == "macos" ]]; then
    _plist="$HOME/Library/LaunchAgents/com.synapse-ai.server.plist"
    if [ -f "$_plist" ]; then
        launchctl unload "$_plist" 2>/dev/null || true
        rm -f "$_plist"
        echo "  Removed macOS LaunchAgent."
    fi
elif [[ "$OS" == "linux" ]]; then
    _service="$HOME/.config/systemd/user/synapse-ai.service"
    if [ -f "$_service" ]; then
        systemctl --user disable synapse-ai.service 2>/dev/null || true
        rm -f "$_service"
        systemctl --user daemon-reload 2>/dev/null || true
        echo "  Removed systemd user service."
    fi
fi

# ---------------------------------------------------------------------------
# 3. Remove data directory (unless --keep-data)
# ---------------------------------------------------------------------------
if ! $KEEP_DATA; then
    for _data in "$HOME/.synapse" "$HOME/.local/share/SynapseAI/data" \
                 "$HOME/Library/Application Support/SynapseAI/data"; do
        if [ -d "$_data" ]; then
            echo "  Removing data: $_data"
            rm -rf "$_data"
        fi
    done
fi

# ---------------------------------------------------------------------------
# 4. Remove installation directory
# ---------------------------------------------------------------------------
if [ -d "$INSTALL_DIR" ]; then
    echo ""
    echo "Removing installation directory: $INSTALL_DIR"
    rm -rf "$INSTALL_DIR/backend/venv" 2>/dev/null || true
    rm -rf "$INSTALL_DIR/frontend/node_modules" 2>/dev/null || true
    rm -rf "$INSTALL_DIR"
    echo "  Done."
else
    echo ""
    echo "Installation directory not found: $INSTALL_DIR"
    echo "  (May already be removed or installed to a custom path.)"
fi

# ---------------------------------------------------------------------------
# 5. Remove pip package (if pip is available)
# ---------------------------------------------------------------------------
echo ""
echo "Removing Python package..."
_pip_cmd=""
for _cmd in pip3 pip python3 python; do
    if command -v "$_cmd" &>/dev/null; then
        _pip_cmd="$_cmd"
        break
    fi
done

if [ -n "$_pip_cmd" ]; then
    if [[ "$_pip_cmd" == "python"* ]]; then
        "$_pip_cmd" -m pip uninstall -y synapse-ai 2>/dev/null \
            && echo "  Removed pip package synapse-ai." \
            || "$_pip_cmd" -m pip uninstall -y synapse 2>/dev/null \
            && echo "  Removed pip package synapse." \
            || echo "  Package not found in pip (may already be removed)."
    else
        "$_pip_cmd" uninstall -y synapse-ai 2>/dev/null \
            && echo "  Removed pip package synapse-ai." \
            || "$_pip_cmd" uninstall -y synapse 2>/dev/null \
            && echo "  Removed pip package synapse." \
            || echo "  Package not found in pip (may already be removed)."
    fi
fi

# ---------------------------------------------------------------------------
# 6. Clean PATH from shell rc files
# ---------------------------------------------------------------------------
echo ""
echo "Cleaning shell profile files..."
for _rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile"; do
    if [ -f "$_rc" ] && grep -qE "SynapseAI|Synapse AI" "$_rc" 2>/dev/null; then
        grep -vE "SynapseAI|Synapse AI" "$_rc" > "$_rc.synapse_bak" \
            && mv "$_rc.synapse_bak" "$_rc" \
            && echo "  Cleaned: $_rc" \
            || rm -f "$_rc.synapse_bak"
    fi
done

echo ""
echo "========================================================"
echo "  Synapse AI has been uninstalled."
if $KEEP_DATA; then
    echo "  Your data directory was preserved."
fi
echo ""
echo "  Open a new terminal to apply PATH changes."
echo "========================================================"
echo ""
