#!/bin/bash

###############################################################################
# Prepare SEER Firewall files for distribution
# Makes all scripts executable and validates file structure
###############################################################################

echo "════════════════════════════════════════════════════════════════"
echo "  SEER Firewall - Prepare for Distribution"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Make all bash scripts executable
echo "Setting executable permissions on scripts..."
chmod +x install.sh 2>/dev/null && echo "  ✓ install.sh"
chmod +x uninstall.sh 2>/dev/null && echo "  ✓ uninstall.sh"
chmod +x create-package.sh 2>/dev/null && echo "  ✓ create-package.sh"

echo ""
echo "Checking required files..."

# Core files
CORE_FILES=(
    "api.py:Python API backend"
    "index.html:Web interface HTML"
    "index.css:Web interface styles"
    "index.js:Web interface JavaScript"
    "database.sql:Database schema"
    "nftables.conf:Firewall configuration"
)

# Scripts
SCRIPT_FILES=(
    "install.sh:Installation script"
    "uninstall.sh:Uninstallation script"
    "update.sh:Git update script"
    "create-package.sh:Package creator"
)

# Documentation
DOC_FILES=(
    "README.md:Main documentation"
    "DEPLOYMENT.md:Deployment guide"
    "GIT_USAGE.md:Git repository guide"
)

ALL_GOOD=true

echo ""
echo "Core Files:"
for file_desc in "${CORE_FILES[@]}"; do
    file="${file_desc%%:*}"
    desc="${file_desc##*:}"
    if [[ -f "$file" ]]; then
        size=$(du -h "$file" | cut -f1)
        printf "  ✓ %-20s %s (%s)\n" "$file" "$desc" "$size"
    else
        printf "  ✗ %-20s %s (MISSING)\n" "$file" "$desc"
        ALL_GOOD=false
    fi
done

echo ""
echo "Scripts:"
for file_desc in "${SCRIPT_FILES[@]}"; do
    file="${file_desc%%:*}"
    desc="${file_desc##*:}"
    if [[ -f "$file" ]]; then
        if [[ -x "$file" ]]; then
            printf "  ✓ %-20s %s (executable)\n" "$file" "$desc"
        else
            printf "  ⚠ %-20s %s (not executable)\n" "$file" "$desc"
        fi
    else
        printf "  ✗ %-20s %s (MISSING)\n" "$file" "$desc"
        ALL_GOOD=false
    fi
done

echo ""
echo "Documentation:"
for file_desc in "${DOC_FILES[@]}"; do
    file="${file_desc%%:*}"
    desc="${file_desc##*:}"
    if [[ -f "$file" ]]; then
        size=$(du -h "$file" | cut -f1)
        printf "  ✓ %-20s %s (%s)\n" "$file" "$desc" "$size"
    else
        printf "  ⚠ %-20s %s (optional, not found)\n" "$file" "$desc"
    fi
done

echo ""
echo "════════════════════════════════════════════════════════════════"

if $ALL_GOOD; then
    echo "  ✓ All required files present!"
    echo ""
    echo "Ready for distribution. Next steps:"
    echo ""
    echo "  1. Create package:  ./create-package.sh"
    echo "  2. Test locally:    sudo ./install.sh"
    echo "  3. Deploy:          See DEPLOYMENT.md"
    echo ""
else
    echo "  ✗ Some required files are missing!"
    echo ""
    echo "Please ensure all files are present before distribution."
    echo ""
    exit 1
fi

echo "════════════════════════════════════════════════════════════════"
