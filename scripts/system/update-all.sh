#!/bin/bash
# ============================================================================
# System Update — Update everything at once
# Managed by Hermes Agent
# ============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🔄 Full System Update${NC}"
echo ""

# --- APT ---
echo -e "${YELLOW}[1/4] APT packages...${NC}"
sudo apt update && sudo apt upgrade -y
echo ""

# --- pip ---
echo -e "${YELLOW}[2/4] Python packages...${NC}"
pip3 list --outdated --format=freeze 2>/dev/null | grep -v '^\-e' | cut -d= -f1 | xargs -r pip3 install --upgrade 2>/dev/null || true
echo ""

# --- npm ---
if command -v npm &>/dev/null; then
    echo -e "${YELLOW}[3/4] npm global packages...${NC}"
    npm update -g 2>/dev/null || true
    echo ""
fi

# --- Hermes ---
echo -e "${YELLOW}[4/4] Hermes Agent...${NC}"
cd ~/.hermes/hermes-agent 2>/dev/null && git pull --ff-only 2>/dev/null && ./install.sh 2>/dev/null && echo "✅ Hermes updated" || echo "⚠️  Hermes update skipped"
echo ""

echo -e "${GREEN}✅ Update complete!${NC}"
