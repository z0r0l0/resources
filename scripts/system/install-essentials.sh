#!/bin/bash
# ============================================================================
# One-Click Install Essential Dev Tools
# Managed by Hermes Agent
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🔧 Installing Essential Development Tools...${NC}"
echo ""

# --- GitHub CLI ---
if ! command -v gh &>/dev/null; then
    echo -e "${YELLOW}Installing gh (GitHub CLI)...${NC}"
    sudo apt install -y gh 2>/dev/null || {
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update && sudo apt install -y gh
    }
else
    echo -e "${GREEN}✅ gh already installed${NC}"
fi

# --- Common Tools ---
TOOLS="bat fd-find fzf htop tmux ripgrep tree httpie jq"
echo -e "${YELLOW}Installing common tools...${NC}"
sudo apt install -y $TOOLS 2>/dev/null && echo -e "${GREEN}✅ Done${NC}" || echo -e "${YELLOW}⚠️  Some tools may not be available${NC}"

# --- Shell completion ---
if command -v gh &>/dev/null; then
    gh completion -s bash > ~/.local/share/bash-completion/completions/gh 2>/dev/null || true
fi

# --- npm global tools ---
if command -v npm &>/dev/null; then
    echo -e "${YELLOW}Installing npm global tools...${NC}"
    npm install -g npm-check-updates trash-cli fast-cli 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}✅ All done!${NC}"
echo -e "   Run 'source ~/.bashrc' to reload, then 'check-env' to verify."
