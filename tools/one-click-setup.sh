#!/bin/bash
# ============================================================================
# ZRL One-Click Environment Setup
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}  ZRL One-Click Environment Setup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""

RESOURCES_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# 1. System config
echo -e "${YELLOW}[1/5] Setting up system configurations...${NC}"
cp "$RESOURCES_DIR/system/shell/.bash_aliases" ~/.bash_aliases 2>/dev/null || true
if ! grep -q "bash_aliases" ~/.bashrc 2>/dev/null; then
    echo -e "\n# Load custom aliases" >> ~/.bashrc
    echo 'if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi' >> ~/.bashrc
fi
echo "  ✅ Aliases configured"

# 2. Install essentials
echo -e "${YELLOW}[2/5] Installing essential tools...${NC}"
bash "$RESOURCES_DIR/scripts/system/install-essentials.sh"
echo ""

# 3. Dev environment
echo -e "${YELLOW}[3/5] Setting up dev environment...${NC}"
echo "  • Python: $(python3 --version)"
echo "  • Node:   $(node --version)"
echo ""

# 4. Git config
echo -e "${YELLOW}[4/5] Configuring Git...${NC}"
git config --global user.name "z0r0l0" 2>/dev/null || true
git config --global user.email "" 2>/dev/null || true
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.st status
git config --global core.autocrlf input
echo "  ✅ Git configured"

# 5. Final checks
echo -e "${YELLOW}[5/5] Running health check...${NC}"
bash "$RESOURCES_DIR/scripts/system/check-env.sh"

echo ""
echo -e "${GREEN}✅ Environment setup complete!${NC}"
echo -e "${GREEN}   Restart your shell or run 'source ~/.bashrc'${NC}"
