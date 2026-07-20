#!/bin/bash
# ============================================================================
# System Environment Check
# Managed by Hermes Agent
# ============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}  ZRL System Health Check${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""

# --- OS ---
echo -e "${GREEN}📦 OS${NC}"
echo "  $(uname -a | cut -d' ' -f1-3)"
echo "  $(lsb_release -d 2>/dev/null | cut -f2)"
echo ""

# --- CPU ---
CORES=$(nproc)
LOAD=$(uptime | awk -F'load average:' '{print $2}')
echo -e "${GREEN}🖥️  CPU${NC}"
echo "  Cores: $CORES"
echo "  Load: $LOAD"
echo ""

# --- Memory ---
echo -e "${GREEN}🧠 Memory${NC}"
free -h | awk 'NR==2{printf "  Total: %s  Used: %s  Available: %s\n", $2, $3, $7}'
echo ""

# --- Disk ---
echo -e "${GREEN}💾 Disk${NC}"
df -h / | tail -1 | awk '{printf "  Total: %s  Used: %s  Avail: %s  Use: %s\n", $2, $3, $4, $5}'
echo ""

# --- Network ---
echo -e "${GREEN}🌐 Network${NC}"
WSL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo "  WSL IP: $WSL_IP"
if timeout 1 bash -c "echo > /dev/tcp/127.0.0.1/7897" 2>/dev/null; then
    echo -e "  Proxy: ${GREEN}✅ Running (127.0.0.1:7897)${NC}"
else
    echo -e "  Proxy: ${YELLOW}❌ Not reachable${NC}"
fi
echo ""

# --- Docker ---
echo -e "${GREEN}🐳 Docker${NC}"
if command -v docker &>/dev/null; then
    if docker info --format '{{.ServerVersion}}' 2>/dev/null; then
        echo -e "  Daemon: ${GREEN}✅ Running${NC}"
    else
        echo -e "  Daemon: ${YELLOW}⚠️  Client only (start with: sudo service docker start)${NC}"
    fi
    echo "  Version: $(docker --version 2>/dev/null)"
else
    echo -e "  ${YELLOW}❌ Not installed${NC}"
fi
echo ""

# --- Dev Tools ---
echo -e "${GREEN}🔧 Dev Tools${NC}"
for tool in python3 node git gh curl jq; do
    if command -v $tool &>/dev/null; then
        VER=$($tool --version 2>/dev/null | head -1)
        echo -e "  ${GREEN}✅${NC} $tool — $VER"
    else
        echo -e "  ${YELLOW}❌${NC} $tool — Not installed"
    fi
done
echo ""

# --- Hermes Gateway ---
echo -e "${GREEN}🤖 Hermes${NC}"
if systemctl --user is-active hermes-gateway &>/dev/null; then
    echo -e "  Gateway: ${GREEN}✅ Active${NC}"
else
    echo -e "  Gateway: ${YELLOW}❌ Inactive${NC}"
fi
echo ""

# --- Disk Space Warning ---
DISK_USED=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USED" -gt 80 ]; then
    echo -e "${RED}⚠️  Disk usage is ${DISK_USED}% — consider cleaning up!${NC}"
fi
echo ""
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
