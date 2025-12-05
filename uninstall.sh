#!/bin/bash

###############################################################################
# SEER Firewall Management System - Uninstaller Script
# Version: 2.0.0
# Description: Removes SEER firewall management system from the device
###############################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/seer"
SERVICE_NAME="seer-firewall"

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

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

stop_service() {
    print_header "Stopping Service"
    
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        systemctl stop ${SERVICE_NAME}
        print_success "Service stopped"
    else
        print_info "Service is not running"
    fi
    
    if systemctl is-enabled --quiet ${SERVICE_NAME}; then
        systemctl disable ${SERVICE_NAME}
        print_success "Service disabled"
    else
        print_info "Service is not enabled"
    fi
}

remove_service() {
    print_header "Removing Service Files"
    
    if [[ -f /etc/systemd/system/${SERVICE_NAME}.service ]]; then
        rm /etc/systemd/system/${SERVICE_NAME}.service
        systemctl daemon-reload
        print_success "Removed systemd service"
    else
        print_info "Service file not found"
    fi
}

remove_installation() {
    print_header "Removing Installation Files"
    
    if [[ -d "$INSTALL_DIR" ]]; then
        # Backup database.sql if it exists
        if [[ -f "$INSTALL_DIR/database.sql" ]]; then
            cp "$INSTALL_DIR/database.sql" "$HOME/database.sql.backup.$(date +%Y%m%d_%H%M%S)"
            print_success "Backed up database.sql"
        fi
        
        rm -rf "$INSTALL_DIR"
        print_success "Removed $INSTALL_DIR"
    else
        print_info "Installation directory not found"
    fi
}

remove_nftables_config() {
    print_header "Firewall Configuration"
    
    read -p "Do you want to remove /etc/nftables.conf? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [[ -f /etc/nftables.conf ]]; then
            # Backup first
            BACKUP_FILE="/tmp/nftables-backup-$(date +%Y%m%d_%H%M%S).conf"
            cp /etc/nftables.conf "$BACKUP_FILE"
            print_success "Backed up nftables.conf to: $BACKUP_FILE"
            
            # Also backup template if it exists
            if [[ -f /etc/nftables.conf.template ]]; then
                cp /etc/nftables.conf.template "$BACKUP_FILE.template"
                rm /etc/nftables.conf.template
                print_success "Removed nftables.conf.template"
            fi
            
            rm /etc/nftables.conf
            print_success "Removed /etc/nftables.conf"
            print_warning "You will need to reconfigure your firewall!"
        else
            print_info "nftables.conf not found"
        fi
    else
        print_info "Keeping nftables configuration"
    fi
}

print_summary() {
    print_header "Uninstallation Complete"
    
    echo ""
    print_success "SEER Firewall Management System has been uninstalled"
    echo ""
    
    echo -e "${BLUE}Removed:${NC}"
    echo "  ✓ Service: ${SERVICE_NAME}"
    echo "  ✓ Installation directory: $INSTALL_DIR"
    
    if [[ -f /etc/nftables.conf ]]; then
        echo ""
        echo -e "${YELLOW}Preserved:${NC}"
        echo "  • Firewall config: /etc/nftables.conf"
    fi
    
    echo ""
    print_info "To reinstall, run: sudo ./install.sh"
    echo ""
}

# Main uninstallation flow
main() {
    clear
    print_header "SEER Firewall Management System - Uninstaller"
    echo ""
    print_warning "This will remove the SEER Firewall Management System"
    echo ""
    read -p "Continue with uninstallation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Uninstallation cancelled"
        exit 0
    fi
    
    echo ""
    check_root
    
    # Stop and remove service
    stop_service
    remove_service
    
    # Remove installation
    remove_installation
    
    # Ask about nftables config
    remove_nftables_config
    
    echo ""
    print_summary
}

# Run main function
main
