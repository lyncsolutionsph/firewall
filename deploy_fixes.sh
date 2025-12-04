#!/bin/bash
#
# Deploy debugging fixes to SEER Firewall
#

set -e

echo "============================================================"
echo "SEER Firewall - Deploy Debugging Fixes"
echo "============================================================"
echo ""

# Check if running as script or sourced
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Installation directory
INSTALL_DIR="/opt/seer-firewall"
DB_DIR="/home/admin/.node-red/seer_database"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (sudo)${NC}"
    exit 1
fi

echo "Step 1: Backing up current files..."
if [ -f "$INSTALL_DIR/api.py" ]; then
    cp "$INSTALL_DIR/api.py" "$INSTALL_DIR/api.py.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${GREEN}✓${NC} Backed up api.py"
else
    echo -e "${YELLOW}!${NC} No existing api.py found"
fi

echo ""
echo "Step 2: Copying updated files..."

# Copy updated api.py
if [ -f "$SCRIPT_DIR/api.py" ]; then
    cp "$SCRIPT_DIR/api.py" "$INSTALL_DIR/"
    echo -e "${GREEN}✓${NC} Copied api.py"
else
    echo -e "${RED}✗${NC} api.py not found in current directory!"
    exit 1
fi

# Copy test script
if [ -f "$SCRIPT_DIR/test_rules.py" ]; then
    cp "$SCRIPT_DIR/test_rules.py" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/test_rules.py"
    echo -e "${GREEN}✓${NC} Copied test_rules.py"
fi

# Copy debugging guide
if [ -f "$SCRIPT_DIR/DEBUGGING_GUIDE.md" ]; then
    cp "$SCRIPT_DIR/DEBUGGING_GUIDE.md" "$INSTALL_DIR/"
    echo -e "${GREEN}✓${NC} Copied DEBUGGING_GUIDE.md"
fi

echo ""
echo "Step 3: Setting permissions..."
chown -R root:root "$INSTALL_DIR"
chmod 755 "$INSTALL_DIR"
chmod 644 "$INSTALL_DIR"/*.py "$INSTALL_DIR"/*.md 2>/dev/null || true
chmod +x "$INSTALL_DIR/test_rules.py" 2>/dev/null || true
echo -e "${GREEN}✓${NC} Permissions set"

echo ""
echo "Step 4: Restarting service..."
systemctl restart seer-firewall
sleep 2

if systemctl is-active --quiet seer-firewall; then
    echo -e "${GREEN}✓${NC} Service restarted successfully"
else
    echo -e "${RED}✗${NC} Service failed to start!"
    echo "Check logs with: journalctl -u seer-firewall -n 50"
    exit 1
fi

echo ""
echo "============================================================"
echo "Deployment Complete!"
echo "============================================================"
echo ""
echo "Next Steps:"
echo "1. Check service logs:"
echo "   sudo journalctl -u seer-firewall -n 100"
echo ""
echo "2. Run diagnostic test:"
echo "   sudo python3 $INSTALL_DIR/test_rules.py"
echo ""
echo "3. Watch logs in real-time:"
echo "   sudo journalctl -u seer-firewall -f"
echo ""
echo "4. Open web interface and try:"
echo "   - Refresh the page (should see rules)"
echo "   - Toggle a rule on/off"
echo "   - Add a new rule"
echo ""
echo "See $INSTALL_DIR/DEBUGGING_GUIDE.md for detailed troubleshooting"
echo ""
