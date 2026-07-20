#!/bin/bash
# ============================================================================
# QQ Bot Gateway Restart
# Managed by Hermes Agent
# ============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}🔄 Restarting Hermes QQ Bot Gateway...${NC}"

# Stop
systemctl --user stop hermes-gateway 2>/dev/null
sleep 2

# Verify stopped
if systemctl --user is-active hermes-gateway &>/dev/null; then
    echo -e "${RED}❌ Failed to stop gateway${NC}"
    exit 1
fi

# Clean lock
rm -f ~/.hermes/gateway.lock
echo "  Lock cleaned"

# Start
systemctl --user start hermes-gateway 2>/dev/null
sleep 3

# Verify started
if systemctl --user is-active hermes-gateway &>/dev/null; then
    echo -e "${GREEN}✅ Gateway restarted successfully${NC}"
    echo ""
    journalctl --user -u hermes-gateway -n 10 --no-pager
else
    echo -e "${RED}❌ Failed to start gateway${NC}"
    journalctl --user -u hermes-gateway -n 20 --no-pager
    exit 1
fi
