chatg#!/bin/bash

###############################################################################
# SEER Firewall Management System - Git Update Script
# Updates an existing installation from git repository
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

check_installation() {
    print_header "Checking Existing Installation"
    
    if [[ ! -d "$INSTALL_DIR" ]]; then
        print_error "SEER Firewall not installed at $INSTALL_DIR"
        print_info "Run install.sh first to install the system"
        exit 1
    fi
    print_success "Installation found at $INSTALL_DIR"
    
    if ! systemctl is-active --quiet ${SERVICE_NAME}; then
        print_warning "Service is not running"
    else
        print_success "Service is running"
    fi
}

check_git_repo() {
    print_header "Checking Git Repository"
    
    # Get the directory where the script is located
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    
    if [[ ! -d "$SCRIPT_DIR/.git" ]]; then
        print_error "Not a git repository"
        print_info "This update script only works with git repositories"
        exit 1
    fi
    print_success "Git repository detected"
    
    # Check if git is installed
    if ! command -v git &> /dev/null; then
        print_error "Git is not installed"
        print_info "Install git: sudo apt install git"
        exit 1
    fi
    print_success "Git is installed"
    
    cd "$SCRIPT_DIR"
    
    # Check for remote
    if ! git remote -v | grep -q "origin"; then
        print_error "No remote repository configured"
        exit 1
    fi
    print_success "Remote repository configured"
    
    # Get current branch
    CURRENT_BRANCH=$(git branch --show-current)
    print_info "Current branch: $CURRENT_BRANCH"
    
    # Show current commit
    CURRENT_COMMIT=$(git rev-parse --short HEAD)
    print_info "Current commit: $CURRENT_COMMIT"
}

pull_updates() {
    print_header "Pulling Updates from Repository"
    
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    cd "$SCRIPT_DIR"
    
    print_info "Fetching latest changes..."
    if ! git fetch origin; then
        print_error "Failed to fetch from remote"
        print_info "Check your network connection and try again"
        exit 1
    fi
    
    # Check if updates are available
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse @{u})
    
    if [[ "$LOCAL" == "$REMOTE" ]]; then
        print_success "Already up to date!"
        read -p "Continue with reinstallation anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Update cancelled"
            exit 0
        fi
    else
        COMMITS_BEHIND=$(git rev-list --count HEAD..@{u})
        print_warning "Your local repository is $COMMITS_BEHIND commit(s) behind"
        
        echo ""
        print_info "Recent changes:"
        git log --oneline HEAD..@{u} | head -5
        echo ""
        
        read -p "Pull these changes? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            print_info "Pulling updates..."
            
            # Check for local changes
            if ! git diff-index --quiet HEAD --; then
                print_warning "You have uncommitted changes"
                read -p "Stash local changes? (Y/n): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                    git stash
                    print_success "Local changes stashed"
                else
                    print_error "Cannot pull with uncommitted changes"
                    exit 1
                fi
            fi
            
            if git pull origin $CURRENT_BRANCH; then
                print_success "Repository updated successfully"
                
                NEW_COMMIT=$(git rev-parse --short HEAD)
                print_info "Updated to commit: $NEW_COMMIT"
            else
                print_error "Failed to pull updates"
                exit 1
            fi
        else
            print_info "Skipping pull"
        fi
    fi
}

backup_database() {
    print_header "Backing Up Database"
    
    if [[ -f "$DB_FILE" ]]; then
        BACKUP_FILE="$DB_FILE.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$DB_FILE" "$BACKUP_FILE"
        print_success "Database backed up to: $BACKUP_FILE"
    else
        print_warning "Database not found, skipping backup"
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
}

update_files() {
    print_header "Updating Application Files"
    
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    
    # Update Python API
    if [[ -f "$SCRIPT_DIR/api.py" ]]; then
        cp "$SCRIPT_DIR/api.py" "$INSTALL_DIR/"
        print_success "Updated api.py"
    fi
    
    # Update web interface files
    if [[ -f "$SCRIPT_DIR/index.html" ]]; then
        cp "$SCRIPT_DIR/index.html" "$INSTALL_DIR/static/"
        print_success "Updated index.html"
    fi
    
    if [[ -f "$SCRIPT_DIR/index.css" ]]; then
        cp "$SCRIPT_DIR/index.css" "$INSTALL_DIR/static/"
        print_success "Updated index.css"
    fi
    
    if [[ -f "$SCRIPT_DIR/index.js" ]]; then
        cp "$SCRIPT_DIR/index.js" "$INSTALL_DIR/static/"
        print_success "Updated index.js"
    fi
    
    # Update database schema (if needed)
    if [[ -f "$SCRIPT_DIR/database.sql" ]]; then
        cp "$SCRIPT_DIR/database.sql" "$INSTALL_DIR/"
        print_success "Updated database.sql"
    fi
}

update_python_packages() {
    print_header "Updating Python Packages"
    
    cd "$INSTALL_DIR"
    
    if [[ -d "venv" ]]; then
        print_info "Updating pip and packages..."
        source venv/bin/activate
        pip install --quiet --upgrade pip flask flask-cors
        print_success "Python packages updated"
        deactivate
    else
        print_warning "Virtual environment not found, skipping package update"
    fi
}

update_nftables_config() {
    print_header "Updating Firewall Configuration"
    
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    
    if [[ -f "$SCRIPT_DIR/nftables.conf" ]]; then
        read -p "Update /etc/nftables.conf? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Backup current config
            cp /etc/nftables.conf /etc/nftables.conf.backup.$(date +%Y%m%d_%H%M%S)
            print_success "Backed up current nftables.conf"
            
            cp "$SCRIPT_DIR/nftables.conf" "/etc/nftables.conf"
            print_success "Updated nftables.conf"
            
            print_info "Reloading firewall..."
            systemctl restart nftables
            print_success "Firewall reloaded"
        else
            print_info "Skipping nftables.conf update"
        fi
    else
        print_warning "nftables.conf not found in repository"
    fi
}

start_service() {
    print_header "Starting Service"
    
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

print_summary() {
    print_header "Update Complete!"
    
    IP_ADDR=$(ip -4 addr show br0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    if [[ -z "$IP_ADDR" ]]; then
        IP_ADDR=$(hostname -I | awk '{print $1}')
    fi
    
    echo ""
    print_success "SEER Firewall Management System updated successfully"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Service Status:${NC}"
    echo "  • Service: ${SERVICE_NAME}"
    echo "  • Status: $(systemctl is-active ${SERVICE_NAME})"
    echo ""
    echo -e "${GREEN}Access Information:${NC}"
    echo "  • Web Interface: http://${IP_ADDR}:5000/"
    echo ""
    echo -e "${GREEN}Useful Commands:${NC}"
    echo "  • Check status: sudo systemctl status ${SERVICE_NAME}"
    echo "  • View logs: sudo journalctl -u ${SERVICE_NAME} -f"
    echo "  • Restart: sudo systemctl restart ${SERVICE_NAME}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Main update flow
main() {
    clear
    print_header "SEER Firewall Management System - Git Update"
    echo ""
    print_info "This script will update your installation from the git repository"
    echo ""
    
    check_root
    check_installation
    check_git_repo
    pull_updates
    
    echo ""
    read -p "Continue with update installation? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        backup_database
        stop_service
        update_files
        update_python_packages
        update_nftables_config
        start_service
        
        echo ""
        print_summary
    else
        print_info "Update cancelled"
        exit 0
    fi
}

# Run main function
main
