#!/bin/bash
# ============================================================================
# Proxy Setup for WSL + Clash Verge Rev
# Managed by Hermes Agent
# ============================================================================

set -e

PROXY_HOST="127.0.0.1"
PROXY_PORT="7897"
PROXY_URL="http://$PROXY_HOST:$PROXY_PORT"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🔌 ZRL Proxy Setup${NC}"
echo ""

# Check if proxy is reachable
if timeout 2 bash -c "echo > /dev/tcp/$PROXY_HOST/$PROXY_PORT" 2>/dev/null; then
    echo -e "${GREEN}✅ Proxy detected at $PROXY_URL${NC}"
else
    echo -e "${YELLOW}⚠️  Proxy not reachable at $PROXY_URL${NC}"
    echo -e "${YELLOW}   Make sure Clash Verge Rev is running on Windows${NC}"
    echo -e "${YELLOW}   → http://127.0.0.1:$PROXY_PORT${NC}"
fi

# Set environment variables
export http_proxy="$PROXY_URL"
export https_proxy="$PROXY_URL"

echo ""
echo -e "${GREEN}📋 Proxy Environment:${NC}"
echo "  http_proxy=$PROXY_URL"
echo "  https_proxy=$PROXY_URL"
echo ""
echo -e "${GREEN}🔧 Commands:${NC}"
echo "  proxy-on     → Enable proxy"
echo "  proxy-off    → Disable proxy"
echo "  proxy-status → Check proxy state"

# Test
if timeout 2 bash -c "echo > /dev/tcp/$PROXY_HOST/$PROXY_PORT" 2>/dev/null; then
    echo ""
    echo -e "${GREEN}🌐 Testing connection...${NC}"
    RESPONSE=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" https://www.google.com 2>/dev/null || echo "failed")
    if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "301" ] || [ "$RESPONSE" = "302" ]; then
        echo -e "${GREEN}✅ Internet access via proxy: OK${NC}"
    else
        echo -e "${YELLOW}⚠️  Proxy connected but internet test returned: $RESPONSE${NC}"
    fi
fi
