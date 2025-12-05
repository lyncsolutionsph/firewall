#!/bin/bash

###############################################################################
# SEER Firewall Management System - Installation Script
# Version: 2.0.0
# Description: Simplified installer for SEER firewall management
###############################################################################

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Main installation
main() {
    clear
    print_header "SEER Firewall Management System - Installer"
    echo ""
    
    # Get the script directory (where install.sh is located)
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    
    # Step 1: Create /opt/seer directory
    print_header "Step 1: Creating /opt/seer Directory"
    sudo mkdir -p /opt/seer
    sudo chown $USER:$USER /opt/seer
    print_success "Directory created and ownership set"
    echo ""
    
    # Step 2: Copy files to /opt/seer and /etc
    print_header "Step 2: Copying Files"
    sudo cp "$SCRIPT_DIR/firewall/database.sql" /opt/seer/
    print_success "Copied database.sql to /opt/seer/"
    
    sudo cp "$SCRIPT_DIR/firewall/api.py" /opt/seer/
    print_success "Copied api.py to /opt/seer/"
    
    sudo cp "$SCRIPT_DIR/firewall/nftables.conf" /etc/nftables.conf
    print_success "Copied nftables.conf to /etc/nftables.conf"
    
    sudo cp "$SCRIPT_DIR/firewall/nftables.conf" /etc/nftables.conf.template
    print_success "Copied nftables.conf to /etc/nftables.conf.template"
    
    sudo cp "$SCRIPT_DIR/firewall/seer-firewall.service" /etc/systemd/system/
    print_success "Copied seer-firewall.service to /etc/systemd/system/"
    echo ""
    
    # Step 3: Setup Python virtual environment
    print_header "Step 3: Setting Up Python Virtual Environment"
    cd /opt/seer
    sudo apt install python3-venv -y
    print_success "Installed python3-venv"
    
    python3 -m venv venv
    print_success "Created virtual environment"
    echo ""
    
    # Step 4: Install Python packages
    print_header "Step 4: Installing Python Packages"
    source venv/bin/activate
    pip install flask flask-cors
    print_success "Installed flask and flask-cors"
    deactivate
    echo ""
    
    # Step 5: Configure and start systemd service
    print_header "Step 5: Configuring Systemd Service"
    sudo systemctl daemon-reload
    print_success "Systemd daemon reloaded"
    
    sudo systemctl enable seer-firewall.service
    print_success "Service enabled"
    
    sudo systemctl start seer-firewall.service
    print_success "Service started"
    echo ""
    
    # Step 6: Check service status
    print_header "Step 6: Checking Service Status"
    sudo systemctl status seer-firewall.service --no-pager
    echo ""
    
    # Summary
    print_header "Installation Complete!"
    echo ""
    print_success "SEER Firewall Management System installed successfully"
    echo ""
    echo -e "${GREEN}Useful Commands:${NC}"
    echo "  • Check status: sudo systemctl status seer-firewall.service"
    echo "  • View logs: sudo journalctl -u seer-firewall.service -f"
    echo "  • Restart: sudo systemctl restart seer-firewall.service"
    echo "  • Stop: sudo systemctl stop seer-firewall.service"
    echo ""
}

# Run main function
main
