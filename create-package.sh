#!/bin/bash

###############################################################################
# SEER Firewall Management System - Package Creator
# Creates a distributable package for easy deployment
###############################################################################

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

VERSION="1.0.0"
PACKAGE_NAME="seer-firewall-${VERSION}"
PACKAGE_DIR="${PACKAGE_NAME}"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  SEER Firewall Package Creator${NC}"
echo -e "${BLUE}  Version: ${VERSION}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if all required files exist
REQUIRED_FILES=(
    "install.sh"
    "uninstall.sh"
    "update.sh"
    "api.py"
    "database.sql"
    "nftables.conf"
    "seer-firewall.service"
)

echo "Checking required files..."
MISSING_FILES=0
for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo -e "${YELLOW}⚠${NC} Missing: $file"
        MISSING_FILES=$((MISSING_FILES + 1))
    else
        echo -e "${GREEN}✓${NC} Found: $file"
    fi
done

if [[ $MISSING_FILES -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}Warning: $MISSING_FILES file(s) missing${NC}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Package creation cancelled"
        exit 1
    fi
fi

echo ""
echo "Creating package directory..."
mkdir -p "$PACKAGE_DIR"

echo "Copying files..."
for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        cp "$file" "$PACKAGE_DIR/"
    fi
done

# Copy README and documentation if exists
for doc in README.md DEPLOYMENT.md; do
    if [[ -f "$doc" ]]; then
        cp "$doc" "$PACKAGE_DIR/"
        echo -e "${GREEN}✓${NC} Copied $doc"
    fi
done

# Create version file
echo "$VERSION" > "$PACKAGE_DIR/VERSION"
echo -e "${GREEN}✓${NC} Created VERSION file"

# Make scripts executable
chmod +x "$PACKAGE_DIR/install.sh"
chmod +x "$PACKAGE_DIR/uninstall.sh"
chmod +x "$PACKAGE_DIR/update.sh"
echo -e "${GREEN}✓${NC} Set executable permissions"

# Create tarball
echo ""
echo "Creating tarball..."
tar -czf "${PACKAGE_NAME}.tar.gz" "$PACKAGE_DIR"
echo -e "${GREEN}✓${NC} Created: ${PACKAGE_NAME}.tar.gz"

# Create zip archive (for Windows users)
if command -v zip &> /dev/null; then
    echo "Creating zip archive..."
    zip -rq "${PACKAGE_NAME}.zip" "$PACKAGE_DIR"
    echo -e "${GREEN}✓${NC} Created: ${PACKAGE_NAME}.zip"
fi

# Calculate checksums
echo ""
echo "Calculating checksums..."
if command -v sha256sum &> /dev/null; then
    sha256sum "${PACKAGE_NAME}.tar.gz" > "${PACKAGE_NAME}.tar.gz.sha256"
    echo -e "${GREEN}✓${NC} Created SHA256 checksum"
fi

# Get file sizes
TARBALL_SIZE=$(du -h "${PACKAGE_NAME}.tar.gz" | cut -f1)

# Create installation instructions file
cat > "$PACKAGE_DIR/INSTALL.txt" << 'EOF'
╔══════════════════════════════════════════════════════════════════════════╗
║           SEER Firewall Management System - Quick Install                ║
╚══════════════════════════════════════════════════════════════════════════╝

INSTALLATION STEPS:
───────────────────────────────────────────────────────────────────────────

1. Transfer this package to your Raspberry Pi:
   
   scp seer-firewall-*.tar.gz admin@<raspberry-pi-ip>:~/

2. SSH into your Raspberry Pi:
   
   ssh admin@<raspberry-pi-ip>

3. Extract the package:
   
   tar -xzf seer-firewall-*.tar.gz
   cd seer-firewall-*/

4. Run the installer:
   
   sudo ./install.sh

5. Follow the on-screen prompts

6. Access the web interface:
   
   http://<raspberry-pi-ip>:5000/

WHAT GETS INSTALLED:
───────────────────────────────────────────────────────────────────────────
• Flask API backend (Python)
• Web management interface (HTML/CSS/JavaScript)
• SQLite database for rule storage
• Systemd service for auto-start
• nftables firewall configuration

SYSTEM REQUIREMENTS:
───────────────────────────────────────────────────────────────────────────
• Raspberry Pi (any model)
• Raspberry Pi OS (Debian-based)
• Python 3.7+
• Root/sudo access
• Internet connection (for initial setup)

USEFUL COMMANDS AFTER INSTALLATION:
───────────────────────────────────────────────────────────────────────────
• Check status:    sudo systemctl status seer-firewall
• View logs:       sudo journalctl -u seer-firewall -f
• Restart:         sudo systemctl restart seer-firewall
• View rules:      sudo nft list ruleset

UNINSTALLATION:
───────────────────────────────────────────────────────────────────────────
To remove the system:

    sudo ./uninstall.sh

This will:
• Stop the service
• Remove installation files
• Optionally backup/remove database
• Optionally remove firewall configuration

SUPPORT:
───────────────────────────────────────────────────────────────────────────
For issues or questions, check the README.md file included in this package.

EOF

echo -e "${GREEN}✓${NC} Created INSTALL.txt"

# Recreate tarball with INSTALL.txt
tar -czf "${PACKAGE_NAME}.tar.gz" "$PACKAGE_DIR"
if command -v zip &> /dev/null; then
    zip -rq "${PACKAGE_NAME}.zip" "$PACKAGE_DIR"
fi

# Cleanup temporary directory
echo ""
echo "Cleaning up..."
rm -rf "$PACKAGE_DIR"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Package created successfully!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Package files:"
echo "  • ${PACKAGE_NAME}.tar.gz (${TARBALL_SIZE})"
if [[ -f "${PACKAGE_NAME}.zip" ]]; then
    ZIP_SIZE=$(du -h "${PACKAGE_NAME}.zip" | cut -f1)
    echo "  • ${PACKAGE_NAME}.zip (${ZIP_SIZE})"
fi
if [[ -f "${PACKAGE_NAME}.tar.gz.sha256" ]]; then
    echo "  • ${PACKAGE_NAME}.tar.gz.sha256"
fi
echo ""
echo "To deploy to a device:"
echo "  1. Copy ${PACKAGE_NAME}.tar.gz to your Raspberry Pi"
echo "  2. Extract: tar -xzf ${PACKAGE_NAME}.tar.gz"
echo "  3. Run: cd ${PACKAGE_NAME} && sudo ./install.sh"
echo ""
