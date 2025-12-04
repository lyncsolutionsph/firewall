#!/bin/bash

###############################################################################
# SEER Firewall Management System - Installation Script
# Version: 1.0.0
# Description: Automated installer for SEER firewall management on Raspberry Pi
###############################################################################

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/seer-firewall"
SERVICE_NAME="seer-firewall"
API_PORT=5000
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
    print_success "Running as root"
}

check_system() {
    print_header "System Check"
    
    # Check if running on Raspberry Pi or Debian-based system
    if [[ ! -f /etc/debian_version ]]; then
        print_error "This script is designed for Debian-based systems (Raspberry Pi OS)"
        exit 1
    fi
    print_success "Debian-based system detected"
    
    # Check if nftables is installed
    if ! command -v nft &> /dev/null; then
        print_warning "nftables not found, will be installed"
    else
        print_success "nftables is installed"
    fi
    
    # Check Python version
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version | awk '{print $2}')
        print_success "Python 3 detected: $PYTHON_VERSION"
    else
        print_error "Python 3 not found"
        exit 1
    fi
}

check_git_repository() {
    print_header "Git Repository Check"
    
    # Get the directory where the script is located
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    
    # Check if this is a git repository
    if [[ -d "$SCRIPT_DIR/.git" ]]; then
        print_info "Git repository detected"
        
        # Check if git is installed
        if ! command -v git &> /dev/null; then
            print_warning "Git not installed, skipping update check"
            return 0
        fi
        
        cd "$SCRIPT_DIR"
        
        # Check if there's a remote configured
        if git remote -v | grep -q "origin"; then
            print_info "Remote repository found"
            
            # Ask if user wants to check for updates
            read -p "Check for updates from remote repository? (Y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                print_info "Fetching latest changes..."
                
                # Fetch from remote
                if git fetch origin 2>/dev/null; then
                    # Check if we're behind
                    LOCAL=$(git rev-parse @)
                    REMOTE=$(git rev-parse @{u} 2>/dev/null)
                    
                    if [[ -n "$REMOTE" ]] && [[ "$LOCAL" != "$REMOTE" ]]; then
                        print_warning "Updates available from remote repository"
                        read -p "Pull latest changes? (Y/n): " -n 1 -r
                        echo
                        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                            print_info "Pulling updates..."
                            if git pull origin $(git branch --show-current) 2>/dev/null; then
                                print_success "Repository updated successfully"
                                print_info "Please re-run the installer with the updated files"
                                exit 0
                            else
                                print_error "Failed to pull updates"
                                read -p "Continue with current version? (y/N): " -n 1 -r
                                echo
                                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                                    print_info "Installation cancelled"
                                    exit 0
                                fi
                            fi
                        else
                            print_info "Continuing with current version"
                        fi
                    else
                        print_success "Repository is up to date"
                    fi
                else
                    print_warning "Could not fetch from remote (check network connection)"
                fi
            else
                print_info "Skipping update check"
            fi
        else
            print_info "No remote repository configured"
        fi
    else
        print_info "Not a git repository, skipping update check"
    fi
    
    cd - > /dev/null
}

install_dependencies() {
    print_header "Installing Dependencies"
    
    print_info "Updating package lists..."
    apt-get update -qq
    
    print_info "Installing required packages..."
    apt-get install -y -qq \
        nftables \
        python3 \
        python3-pip \
        python3-venv \
        sqlite3 \
        curl \
        git \
        || { print_error "Failed to install system packages"; exit 1; }
    
    print_success "System packages installed"
    
    # Enable nftables service
    systemctl enable nftables
    print_success "nftables service enabled"
}

create_directories() {
    print_header "Creating Directory Structure"
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/static"
    mkdir -p "$INSTALL_DIR/logs"
    mkdir -p "$DB_DIR"
    
    print_success "Created $INSTALL_DIR"
    print_success "Created $DB_DIR"
}

copy_files() {
    print_header "Copying Application Files"
    
    # Get the directory where the script is located
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    
    # Copy Python API
    if [[ -f "$SCRIPT_DIR/api.py" ]]; then
        cp "$SCRIPT_DIR/api.py" "$INSTALL_DIR/"
        print_success "Copied api.py"
    else
        print_error "api.py not found in $SCRIPT_DIR"
        exit 1
    fi
    
    # Copy web interface files
    if [[ -f "$SCRIPT_DIR/index.html" ]]; then
        cp "$SCRIPT_DIR/index.html" "$INSTALL_DIR/static/"
        print_success "Copied index.html"
    else
        print_error "index.html not found"
        exit 1
    fi
    
    if [[ -f "$SCRIPT_DIR/index.css" ]]; then
        cp "$SCRIPT_DIR/index.css" "$INSTALL_DIR/static/"
        print_success "Copied index.css"
    else
        print_error "index.css not found"
        exit 1
    fi
    
    if [[ -f "$SCRIPT_DIR/index.js" ]]; then
        cp "$SCRIPT_DIR/index.js" "$INSTALL_DIR/static/"
        print_success "Copied index.js"
    else
        print_error "index.js not found"
        exit 1
    fi
    
    # Copy database schema
    if [[ -f "$SCRIPT_DIR/database.sql" ]]; then
        cp "$SCRIPT_DIR/database.sql" "$INSTALL_DIR/"
        print_success "Copied database.sql"
    else
        print_warning "database.sql not found (optional)"
    fi
    
    # Copy nftables configuration
    if [[ -f "$SCRIPT_DIR/nftables.conf" ]]; then
        cp "$SCRIPT_DIR/nftables.conf" "/etc/nftables.conf"
        print_success "Copied nftables.conf to /etc/nftables.conf"
    else
        print_warning "nftables.conf not found (will use existing)"
    fi
}

setup_python_environment() {
    print_header "Setting Up Python Environment"
    
    cd "$INSTALL_DIR"
    
    # Create virtual environment
    print_info "Creating Python virtual environment..."
    python3 -m venv venv
    print_success "Virtual environment created"
    
    # Activate virtual environment and install packages
    print_info "Installing Python packages..."
    source venv/bin/activate
    
    pip install --quiet --upgrade pip
    pip install --quiet flask flask-cors
    
    print_success "Python packages installed"
    deactivate
}

initialize_database() {
    print_header "Initializing Database"
    
    if [[ -f "$DB_FILE" ]]; then
        print_warning "Database already exists at $DB_FILE"
        read -p "Do you want to backup and reinitialize? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            BACKUP_FILE="$DB_FILE.backup.$(date +%Y%m%d_%H%M%S)"
            cp "$DB_FILE" "$BACKUP_FILE"
            print_success "Backed up existing database to $BACKUP_FILE"
        else
            print_info "Keeping existing database"
            return
        fi
    fi
    
    # Initialize database with schema
    if [[ -f "$INSTALL_DIR/database.sql" ]]; then
        print_info "Creating database tables..."
        sqlite3 "$DB_FILE" < "$INSTALL_DIR/database.sql"
        print_success "Database initialized"
    else
        print_warning "No database.sql found, skipping initialization"
    fi
    
    # Set proper permissions
    chown -R admin:admin "$DB_DIR" 2>/dev/null || chown -R $(whoami):$(whoami) "$DB_DIR"
    chmod 755 "$DB_DIR"
    chmod 644 "$DB_FILE"
    print_success "Database permissions set"
}

create_systemd_service() {
    print_header "Creating Systemd Service"
    
    cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=SEER Firewall Management API
After=network.target nftables.service
Wants=nftables.service

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$INSTALL_DIR/venv/bin"
ExecStart=$INSTALL_DIR/venv/bin/python3 $INSTALL_DIR/api.py
Restart=always
RestartSec=10
StandardOutput=append:$INSTALL_DIR/logs/api.log
StandardError=append:$INSTALL_DIR/logs/api.error.log

[Install]
WantedBy=multi-user.target
EOF
    
    print_success "Created systemd service: ${SERVICE_NAME}.service"
    
    # Reload systemd
    systemctl daemon-reload
    print_success "Systemd daemon reloaded"
}

configure_firewall() {
    print_header "Configuring Firewall"
    
    print_info "Loading nftables configuration..."
    
    # Backup current rules
    nft list ruleset > /tmp/nftables-backup-$(date +%Y%m%d_%H%M%S).conf
    print_success "Backed up current nftables rules to /tmp/"
    
    # Load new configuration
    if [[ -f /etc/nftables.conf ]]; then
        systemctl restart nftables
        print_success "nftables configuration loaded"
    else
        print_warning "No nftables.conf found, skipping"
    fi
    
    # Add rule to allow API access
    print_info "Ensuring API port $API_PORT is accessible from LAN..."
    # This will be handled by the nftables.conf, just inform user
    print_success "Firewall configured"
}

start_service() {
    print_header "Starting Service"
    
    # Enable and start service
    systemctl enable ${SERVICE_NAME}
    systemctl start ${SERVICE_NAME}
    
    # Wait a moment for service to start
    sleep 2
    
    # Check service status
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        print_success "Service started successfully"
    else
        print_error "Service failed to start"
        print_info "Check logs with: journalctl -u ${SERVICE_NAME} -n 50"
        exit 1
    fi
}

detect_ip_address() {
    # Try to detect LAN IP address
    LAN_IP=$(ip -4 addr show br0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    if [[ -z "$LAN_IP" ]]; then
        LAN_IP=$(hostname -I | awk '{print $1}')
    fi
    echo "$LAN_IP"
}

print_summary() {
    print_header "Installation Complete!"
    
    IP_ADDR=$(detect_ip_address)
    
    echo ""
    print_success "SEER Firewall Management System installed successfully"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Service Status:${NC}"
    echo "  • Service: ${SERVICE_NAME}"
    echo "  • Status: $(systemctl is-active ${SERVICE_NAME})"
    echo ""
    echo -e "${GREEN}Access Information:${NC}"
    echo "  • Web Interface: http://${IP_ADDR}:${API_PORT}/"
    echo "  • API Endpoint: http://${IP_ADDR}:${API_PORT}/api/"
    echo ""
    echo -e "${GREEN}File Locations:${NC}"
    echo "  • Installation: $INSTALL_DIR"
    echo "  • Database: $DB_FILE"
    echo "  • Logs: $INSTALL_DIR/logs/"
    echo "  • Config: /etc/nftables.conf"
    echo ""
    echo -e "${GREEN}Useful Commands:${NC}"
    echo "  • Check status: sudo systemctl status ${SERVICE_NAME}"
    echo "  • View logs: sudo journalctl -u ${SERVICE_NAME} -f"
    echo "  • Restart: sudo systemctl restart ${SERVICE_NAME}"
    echo "  • Stop: sudo systemctl stop ${SERVICE_NAME}"
    echo "  • View firewall rules: sudo nft list ruleset"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    print_info "Open your web browser and navigate to: http://${IP_ADDR}:${API_PORT}/"
    echo ""
}

# Main installation flow
main() {
    clear
    print_header "SEER Firewall Management System - Installer"
    echo ""
    print_info "This script will install the SEER Firewall Management System"
    echo ""
    read -p "Continue with installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled"
        exit 0
    fi
    
    echo ""
    check_root
    check_system
    check_git_repository
    install_dependencies
    create_directories
    copy_files
    setup_python_environment
    initialize_database
    create_systemd_service
    configure_firewall
    start_service
    
    echo ""
    print_summary
}

# Run main function
main
echo ""
echo "Testing API..."
sleep 2
curl -s http://localhost:5000/api/status | python3 -m json.tool

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "API is running on: http://localhost:5000"
echo "Database location: $DB_PATH"
echo ""
echo "Test toggle a rule:"
echo "curl -X POST http://localhost:5000/api/rules/9/toggle \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"field\":\"rule_enabled\",\"value\":0}'"
echo ""
echo "View logs:"
echo "sudo journalctl -u seer-firewall.service -f"
echo ""
