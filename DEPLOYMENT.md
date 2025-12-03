# SEER Firewall Deployment Guide

## Quick Start for Device Updates

This guide is for deploying SEER Firewall Management System to multiple Raspberry Pi devices.

---

## Method 1: Package Deployment (Recommended)

### Step 1: Create Distribution Package

On your development machine (where you have all the files):

```bash
# Make the package creator executable
chmod +x create-package.sh

# Create the distribution package
./create-package.sh
```

This creates `seer-firewall-1.0.0.tar.gz` containing everything needed.

### Step 2: Transfer to Target Device

```bash
# Replace <device-ip> with the Raspberry Pi's IP address
scp seer-firewall-1.0.0.tar.gz admin@<device-ip>:~/
```

Example:
```bash
scp seer-firewall-1.0.0.tar.gz admin@192.168.50.10:~/
```

### Step 3: Install on Target Device

```bash
# SSH into the device
ssh admin@<device-ip>

# Extract the package
tar -xzf seer-firewall-1.0.0.tar.gz
cd seer-firewall-1.0.0/

# Run installer
sudo ./install.sh
```

### Step 4: Verify Installation

```bash
# Check service status
sudo systemctl status seer-firewall

# View logs
sudo journalctl -u seer-firewall -n 50

# Test API
curl http://localhost:5000/api/rules
```

### Step 5: Access Web Interface

Open browser: `http://<device-ip>:5000/`

---

## Method 2: USB/SD Card Deployment

### Step 1: Create Package

```bash
./create-package.sh
```

### Step 2: Copy to USB Drive

```bash
# Mount USB drive and copy
cp seer-firewall-1.0.0.tar.gz /media/usb/
```

### Step 3: Install from USB on Target Device

```bash
# Insert USB on Raspberry Pi
# Mount (usually auto-mounted at /media/pi/<drive-name>)

# Copy to home
cp /media/pi/<drive-name>/seer-firewall-1.0.0.tar.gz ~/

# Extract and install
tar -xzf seer-firewall-1.0.0.tar.gz
cd seer-firewall-1.0.0/
sudo ./install.sh
```

---

## Method 3: Direct File Copy (Development)

For quick updates during development:

```bash
# Copy individual files
scp api.py admin@<device-ip>:/opt/seer-firewall/
scp index.html admin@<device-ip>:/opt/seer-firewall/static/
scp index.css admin@<device-ip>:/opt/seer-firewall/static/
scp index.js admin@<device-ip>:/opt/seer-firewall/static/

# Restart service
ssh admin@<device-ip> 'sudo systemctl restart seer-firewall'
```

---

## Bulk Deployment Script

For deploying to multiple devices, create `deploy-all.sh`:

```bash
#!/bin/bash

# List of device IPs
DEVICES=(
    "192.168.50.10"
    "192.168.50.11"
    "192.168.50.12"
)

PACKAGE="seer-firewall-1.0.0.tar.gz"
USER="admin"

for device in "${DEVICES[@]}"; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Deploying to: $device"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Transfer package
    echo "→ Transferring package..."
    scp -q "$PACKAGE" ${USER}@${device}:~/
    
    # Install
    echo "→ Installing..."
    ssh ${USER}@${device} << 'ENDSSH'
        cd ~
        tar -xzf seer-firewall-*.tar.gz
        cd seer-firewall-*/
        sudo ./install.sh <<< 'y'
ENDSSH
    
    echo "✓ Deployment to $device complete"
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "All deployments complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

Usage:
```bash
chmod +x deploy-all.sh
./deploy-all.sh
```

---

## Update Existing Installation

To update an already-installed system:

```bash
# On the device
cd ~/seer-firewall-1.0.0/

# Stop service
sudo systemctl stop seer-firewall

# Backup database
cp /home/admin/.node-red/seer_database/seer.db ~/seer-backup.db

# Copy updated files
sudo cp api.py /opt/seer-firewall/
sudo cp static/* /opt/seer-firewall/static/

# Restart service
sudo systemctl restart seer-firewall
```

---

## Pre-Deployment Checklist

Before deploying to devices:

- [ ] Test on development device
- [ ] Verify all custom rules work
- [ ] Backup existing configurations
- [ ] Document any custom network settings
- [ ] Test rollback procedure
- [ ] Verify database migrations
- [ ] Check firewall rule syntax
- [ ] Test from LAN, Tailscale, and WAN (if applicable)

---

## Post-Deployment Verification

After installing on each device:

```bash
# Check service
sudo systemctl status seer-firewall

# Check database
sqlite3 /home/admin/.node-red/seer_database/seer.db "SELECT COUNT(*) FROM policy_rules;"

# Check firewall
sudo nft list ruleset | head -20

# Test web access (from browser)
http://<device-ip>:5000/

# Test API
curl http://<device-ip>:5000/api/rules
```

---

## Rollback Procedure

If something goes wrong:

```bash
# Method 1: Use uninstaller
cd ~/seer-firewall-1.0.0/
sudo ./uninstall.sh

# Method 2: Manual cleanup
sudo systemctl stop seer-firewall
sudo systemctl disable seer-firewall
sudo rm /etc/systemd/system/seer-firewall.service
sudo rm -rf /opt/seer-firewall
sudo systemctl daemon-reload

# Restore database backup
cp ~/seer-backup.db /home/admin/.node-red/seer_database/seer.db

# Restore nftables config
sudo cp /tmp/nftables-backup-*.conf /etc/nftables.conf
sudo systemctl restart nftables
```

---

## Troubleshooting Deployment Issues

### Package transfer fails
```bash
# Check SSH access
ssh admin@<device-ip> 'echo "SSH works"'

# Check network connectivity
ping <device-ip>

# Use verbose mode
scp -v seer-firewall-1.0.0.tar.gz admin@<device-ip>:~/
```

### Installation fails
```bash
# Check logs
sudo journalctl -xe

# Verify permissions
ls -la /opt/seer-firewall

# Check Python environment
/opt/seer-firewall/venv/bin/python3 --version

# Manually run installer steps
cd ~/seer-firewall-1.0.0
cat install.sh  # Review what failed
```

### Service won't start
```bash
# Check detailed logs
sudo journalctl -u seer-firewall -n 100

# Test API manually
cd /opt/seer-firewall
./venv/bin/python3 api.py

# Check port availability
sudo netstat -tulpn | grep 5000
```

### Database errors
```bash
# Verify database exists
ls -la /home/admin/.node-red/seer_database/seer.db

# Check schema
sqlite3 /home/admin/.node-red/seer_database/seer.db ".schema"

# Reinitialize if needed
cd /opt/seer-firewall
sqlite3 /home/admin/.node-red/seer_database/seer.db < database.sql
```

---

## Network-Specific Configuration

If devices have different network configurations:

### Edit before deployment:

**nftables.conf**:
```bash
# Update interface names
define WAN_IF = "eth1"      # Change if different
define LAN_IF = "br0"       # Change if different

# Update network ranges
define LAN_NET = "192.168.50.0/24"  # Change to match
define TAILNET = "100.64.0.0/10"    # Usually same
```

**api.py** (if needed):
```python
# Line ~40: Update database path if different
DB_PATH = '/home/admin/.node-red/seer_database/seer.db'
```

---

## Support & Maintenance

### Regular Maintenance Tasks

```bash
# Weekly: Check logs for errors
sudo journalctl -u seer-firewall --since "7 days ago" | grep -i error

# Monthly: Backup database
cp /home/admin/.node-red/seer_database/seer.db \
   ~/backups/seer-$(date +%Y%m%d).db

# As needed: Update rules
# Use web interface or API
```

### Monitoring

```bash
# Service uptime
systemctl show seer-firewall --property=ActiveState,SubState

# API response
curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/api/rules

# Database size
du -h /home/admin/.node-red/seer_database/seer.db

# Firewall rule count
sudo nft list ruleset | grep -c "Custom Rule"
```

---

## Quick Reference

| Task | Command |
|------|---------|
| Create package | `./create-package.sh` |
| Transfer to device | `scp package.tar.gz admin@<ip>:~/` |
| Extract | `tar -xzf package.tar.gz` |
| Install | `cd package/ && sudo ./install.sh` |
| Check status | `sudo systemctl status seer-firewall` |
| View logs | `sudo journalctl -u seer-firewall -f` |
| Restart | `sudo systemctl restart seer-firewall` |
| Uninstall | `sudo ./uninstall.sh` |
| Web UI | `http://<device-ip>:5000/` |

---

## Version Control

Keep track of deployments:

```bash
# Create deployment log
cat >> deployment-log.txt << EOF
Date: $(date)
Version: 1.0.0
Device: <device-ip>
Status: Success
Notes: Initial deployment
EOF
```

---

**End of Deployment Guide**
