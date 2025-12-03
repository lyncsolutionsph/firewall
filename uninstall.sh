#!/bin/bash

###############################################################################
# SEER Firewall Management System - Uninstaller Script
# Version: 1.0.0
# Description: Removes SEER firewall management system from the device
###############################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/seer-firewall"
SERVICE_NAME="seer-firewall"
DB_DIR="/home/admin/.node-red/seer_database"
DB_FILE="$DB_DIR/seer.db"

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
        rm -rf "$INSTALL_DIR"
        print_success "Removed $INSTALL_DIR"
    else
        print_info "Installation directory not found"
    fi
}

backup_database() {
    print_header "Database Backup"
    
    if [[ -f "$DB_FILE" ]]; then
        read -p "Do you want to backup the database before removal? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            BACKUP_FILE="$HOME/seer-database-backup-$(date +%Y%m%d_%H%M%S).db"
            cp "$DB_FILE" "$BACKUP_FILE"
            print_success "Database backed up to: $BACKUP_FILE"
            return 0
        else
            print_info "Skipping database backup"
            return 1
        fi
    else
        print_info "Database not found"
        return 1
    fi
}

remove_database() {
    print_header "Removing Database"
    
    read -p "Do you want to remove the database (including all firewall rules)? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [[ -f "$DB_FILE" ]]; then
            rm "$DB_FILE"
            print_success "Database removed"
        fi
        
        # Remove directory if empty
        if [[ -d "$DB_DIR" ]] && [[ -z "$(ls -A $DB_DIR)" ]]; then
            rm -rf "$DB_DIR"
            print_success "Removed empty database directory"
        fi
    else
        print_info "Keeping database at: $DB_FILE"
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

clean_custom_rules() {
    print_header "Cleaning Custom Firewall Rules"
    
    print_info "Removing custom rules from nftables..."
    
    # Try to remove custom rules by comment
    nft list ruleset | grep "Custom Rule" | wc -l | read RULE_COUNT
    
    if [[ -n "$RULE_COUNT" ]] && [[ "$RULE_COUNT" -gt 0 ]]; then
        print_warning "Found $RULE_COUNT custom rules in nftables"
        read -p "Remove these rules? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            # Remove rules from all chains
            for chain in input forward output; do
                while true; do
                    HANDLE=$(nft -a list chain inet filter $chain 2>/dev/null | grep "Custom Rule" | head -1 | grep -oP 'handle \K[0-9]+')
                    if [[ -z "$HANDLE" ]]; then
                        break
                    fi
                    nft delete rule inet filter $chain handle $HANDLE 2>/dev/null
                done
            done
            print_success "Custom rules removed from nftables"
        else
            print_info "Keeping custom rules in nftables"
        fi
    else
        print_info "No custom rules found in nftables"
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
    
    if [[ -f "$DB_FILE" ]]; then
        echo ""
        echo -e "${YELLOW}Preserved:${NC}"
        echo "  • Database: $DB_FILE"
    fi
    
    if [[ -f /etc/nftables.conf ]]; then
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
    
    # Backup database before any changes
    backup_database
    
    # Stop and remove service
    stop_service
    remove_service
    
    # Clean up custom rules from firewall
    clean_custom_rules
    
    # Remove installation
    remove_installation
    
    # Ask about database
    remove_database
    
    # Ask about nftables config
    remove_nftables_config
    
    echo ""
    print_summary
}

# Run main function
main
