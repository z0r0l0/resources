#!/bin/bash
# ============================================================================
# Environment Setup — source this in .bashrc
# Managed by Hermes Agent
# ============================================================================

# --- PATH ---
export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"

# --- Editor ---
export EDITOR="code"
export VISUAL="code"

# --- Node ---
export NPM_DIR="$HOME/.npm-global"
mkdir -p "$NPM_DIR"
npm config set prefix "$NPM_DIR" 2>/dev/null || true

# --- Python ---
export PIP_REQUIRE_VIRTUALENV=false

# --- Proxy (auto-detect) ---
if command -v powershell.exe &>/dev/null; then
    # Check if Clash Verge is running on Windows
    PROXY_HOST="127.0.0.1"
    PROXY_PORT="7897"
    if timeout 1 bash -c "echo > /dev/tcp/$PROXY_HOST/$PROXY_PORT" 2>/dev/null; then
        export http_proxy="http://$PROXY_HOST:$PROXY_PORT"
        export https_proxy="http://$PROXY_HOST:$PROXY_PORT"
        echo "🌐 Proxy detected: http://$PROXY_HOST:$PROXY_PORT"
    fi
fi

# --- Locale ---
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# --- History ---
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth:erasedups
