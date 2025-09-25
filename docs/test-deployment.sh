#!/bin/bash
set -e

echo "🧪 Testing Temporal Quadlet Deployment"
echo "======================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test functions
test_service_status() {
    local service=$1
    echo -n "Testing $service status... "
    if systemctl --user is-active --quiet $service; then
        echo -e "${GREEN}✓ Active${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed${NC}"
        return 1
    fi
}

test_container_running() {
    local container=$1
    echo -n "Testing $container container... "
    if podman ps --format "{{.Names}}" | grep -q "^$container$"; then
        echo -e "${GREEN}✓ Running${NC}"
        return 0
    else
        echo -e "${RED}✗ Not running${NC}"
        return 1
    fi
}

test_network_connectivity() {
    local url=$1
    local name=$2
    echo -n "Testing $name connectivity... "
    if curl -s -f -k --max-time 10 $url > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Connected${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed${NC}"
        return 1
    fi
}

test_port_open() {
    local port=$1
    local name=$2
    echo -n "Testing $name port $port... "
    if ss -tuln | grep -q ":$port "; then
        echo -e "${GREEN}✓ Open${NC}"
        return 0
    else
        echo -e "${RED}✗ Closed${NC}"
        return 1
    fi
}

# Main test sequence
echo "📋 Step 1: Service Status Checks"
echo "---------------------------------"
test_service_status "temporal-network.service"
test_service_status "temporal-server.service" 
test_service_status "temporal-ui.service"
test_service_status "temporal-nginx.service"

echo ""
echo "🐳 Step 2: Container Status Checks"
echo "-----------------------------------"
test_container_running "temporal-server"
test_container_running "temporal-ui"
test_container_running "temporal-nginx"

echo ""
echo "🌐 Step 3: Network Connectivity Tests"
echo "--------------------------------------"
test_port_open "7233" "Temporal gRPC"
test_port_open "80" "HTTP"
test_port_open "443" "HTTPS"

echo ""
test_network_connectivity "http://localhost/health" "Nginx health check"
test_network_connectivity "https://localhost/health" "Nginx HTTPS health check"

echo ""
echo "🔧 Step 4: Temporal Specific Tests"
echo "-----------------------------------"

# Test Temporal server health
echo -n "Testing Temporal server health... "
if timeout 10 temporal --address localhost:7233 operator cluster health >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Healthy${NC}"
else
    echo -e "${YELLOW}⚠ Command failed (may not have temporal CLI)${NC}"
fi

# Test database files
echo -n "Testing SQLite database files... "
if [ -f ~/data/sqlite/temporal.db ]; then
    echo -e "${GREEN}✓ Database exists${NC}"
else
    echo -e "${YELLOW}⚠ Database not found (may not be created yet)${NC}"
fi

echo ""
echo "📊 Step 5: System Information"
echo "------------------------------"
echo "Podman version: $(podman --version)"
echo "Active containers: $(podman ps | wc -l)"
echo "Available networks: $(podman network ls | wc -l)"

echo ""
echo "📂 File Structure Check:"
echo "SQLite data: $(ls -la ~/data/sqlite/ 2>/dev/null | wc -l) files"
echo "Nginx certs: $(ls -la ~/data/nginx-certs/ 2>/dev/null | wc -l) files"
echo "Temporal config: $(ls -la ~/config/temporal/ 2>/dev/null | wc -l) files"

echo ""
echo "🏁 Test Summary"
echo "==============="

# Count successful tests (this is a simple approach)
if systemctl --user is-active --quiet temporal-server.service && \
   systemctl --user is-active --quiet temporal-ui.service && \
   systemctl --user is-active --quiet temporal-nginx.service; then
    echo -e "${GREEN}✅ Core services are running successfully!${NC}"
    echo ""
    echo "🎯 Access Points:"
    echo "   • Web UI: https://localhost (or https://temporal.local)"
    echo "   • gRPC API: localhost:7233"
    echo "   • Health Check: https://localhost/health"
    echo ""
    echo "📝 Next Steps:"
    echo "   • Update /etc/hosts with: <pi-ip> temporal.local"
    echo "   • Test from external client: temporal.local or <pi-ip>:7233"
    echo "   • Create your first workflow!"
else
    echo -e "${RED}❌ Some services are not running properly${NC}"
    echo ""
    echo "🔍 Debugging Commands:"
    echo "   systemctl --user status temporal-server.service"
    echo "   journalctl --user -u temporal-server.service -f"
    echo "   podman logs temporal-server"
fi