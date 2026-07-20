#!/bin/bash
# ============================================================================
# QQ Bot Gateway Health Check
# Managed by Hermes Agent
# ============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🤖 QQ Bot Gateway Health Check${NC}"
echo ""

# Check systemd service
if systemctl --user is-active hermes-gateway &>/dev/null; then
    echo -e "  Service: ${GREEN}✅ Active${NC}"
else
    echo -e "  Service: ${RED}❌ Inactive${NC}"
fi

# Check gateway lock file
if [ -f ~/.hermes/gateway.lock ]; then
    echo -e "  Lock file: ${GREEN}✅ Exists${NC}"
else
    echo -e "  Lock file: ${YELLOW}⚠️  Missing${NC}"
fi

# Check QQ config in env
if grep -q "QQ_APP_ID" ~/.hermes/.env 2>/dev/null; then
    APP_ID=$(grep "QQ_APP_ID" ~/.hermes/.env | cut -d= -f2)
    echo -e "  QQ App ID: ${GREEN}✅ $APP_ID${NC}"
else
    echo -e "  QQ App ID: ${RED}❌ Not configured${NC}"
fi

# Check recent logs for errors
if journalctl --user -u hermes-gateway -n 20 --no-pager 2>/dev/null | grep -qi "error\|failed\|exception"; then
    echo -e "  Recent errors: ${YELLOW}⚠️  Found in logs (use hermes-log to see)${NC}"
else
    echo -e "  Recent errors: ${GREEN}✅ None${NC}"
fi

echo ""
# Last restart time
LAST_RESTART=$(journalctl --user -u hermes-gateway --no-pager 2>/dev/null | grep "Started" | tail -1 | cut -d' ' -f1-3)
if [ -n "$LAST_RESTART" ]; then
    echo -e "  Last restart: $LAST_RESTART"
fi
