#!/bin/bash
# Deploy Custom Rules Persistence
# Run this script on your Raspberry Pi to enable persistent custom rules

set -e

echo "================================================"
echo "SEER Firewall - Custom Rules Persistence Setup"
echo "================================================"
echo ""

# Check if running as admin user
if [ "$USER" != "admin" ]; then
    echo "⚠ Warning: This script should be run as 'admin' user"
    echo "Current user: $USER"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Step 1: Run database migration..."
python3 migrate_custom_rules.py
if [ $? -ne 0 ]; then
    echo "✗ Migration failed!"
    exit 1
fi

echo ""
echo "Step 2: Verify database table..."
sqlite3 /home/admin/.node-red/seer_database/seer.db "SELECT name FROM sqlite_master WHERE type='table' AND name='custom_rules';"
if [ $? -eq 0 ]; then
    echo "✓ custom_rules table exists"
else
    echo "✗ Table verification failed"
    exit 1
fi

echo ""
echo "Step 3: Check Flask API service..."
if systemctl is-active --quiet seer-firewall; then
    echo "✓ seer-firewall service is running"
    echo ""
    echo "Restarting service to load new API endpoints..."
    sudo systemctl restart seer-firewall
    sleep 3
    
    if systemctl is-active --quiet seer-firewall; then
        echo "✓ Service restarted successfully"
    else
        echo "✗ Service failed to restart"
        echo "Check logs: journalctl -u seer-firewall -n 50"
        exit 1
    fi
else
    echo "⚠ seer-firewall service is not running"
    echo "Start it manually: sudo systemctl start seer-firewall"
fi

echo ""
echo "Step 4: Test API endpoint..."
sleep 2
curl -s http://localhost:5000/api/custom-rules > /dev/null
if [ $? -eq 0 ]; then
    echo "✓ API endpoint responding"
else
    echo "⚠ API endpoint not responding (might be starting up)"
fi

echo ""
echo "================================================"
echo "✓ Setup Complete!"
echo "================================================"
echo ""
echo "What's Changed:"
echo "  • Custom rules now stored in SQLite database"
echo "  • Rules persist across reboots"
echo "  • Automatic restoration on startup"
echo ""
echo "Next Steps:"
echo "  1. Open SEER Firewall UI"
echo "  2. Add a custom rule (e.g., port 8080)"
echo "  3. Reboot your system: sudo reboot"
echo "  4. After reboot, verify rule still exists"
echo ""
echo "Troubleshooting:"
echo "  • View logs: journalctl -u seer-firewall -f"
echo "  • Check DB: sqlite3 /home/admin/.node-red/seer_database/seer.db"
echo "  • Test API: curl http://localhost:5000/api/custom-rules"
echo ""
