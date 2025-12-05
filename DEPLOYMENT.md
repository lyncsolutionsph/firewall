# SEER Firewall Deployment Guide

## Overview

This guide covers deploying the SEER Firewall Management System to one or multiple devices. The system is designed for easy installation via Git clone or package deployment.

---

## Method 1: Direct Git Clone (Recommended)

### Single Device Installation

The simplest method for deploying to a single device:

```bash
# SSH into target device
ssh admin@<device-ip>

# Create installation directory
sudo mkdir -p /opt/seer
sudo chown $USER:$USER /opt/seer

# Clone repository
git clone https://github.com/lyncsolutionsph/firewall

# Install
cd firewall
sudo ./install.sh
```

### Verify Installation

```bash
# Check service status
sudo systemctl status seer-firewall.service

# View logs
sudo journalctl -u seer-firewall.service -f

# Test API
curl http://localhost:5000/api/status
```

---

## Method 2: Package Deployment

For deploying to multiple devices or offline installations.

### Step 1: Create Distribution Package

On your development machine:

```bash
# Clone repository (if not already)
git clone https://github.com/lyncsolutionsph/firewall
cd firewall

# Create package (optional - can also just zip the repo)
tar -czf seer-firewall.tar.gz \
  install.sh uninstall.sh update.sh \
  api.py database.sql nftables.conf \
  seer-firewall.service \
  README.md DEPLOYMENT.md
```

### Step 2: Transfer to Target Device

```bash
# Via SCP
scp seer-firewall.tar.gz admin@<device-ip>:~/

# Or copy to USB drive
cp seer-firewall.tar.gz /media/usb/
```

### Step 3: Install on Target Device

```bash
# SSH into device
ssh admin@<device-ip>

# Extract package
tar -xzf seer-firewall.tar.gz
cd firewall/

# Run installer
sudo ./install.sh
```

---

## Method 3: Bulk Deployment

For deploying to multiple devices, create a deployment script:

```bash
#!/bin/bash
# deploy-multiple.sh

# List of device IPs
DEVICES=(
    "192.168.50.10"
    "192.168.50.11"
    "192.168.50.12"
)

USER="admin"
REPO_URL="https://github.com/lyncsolutionsph/firewall"

for device in "${DEVICES[@]}"; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Deploying to: $device"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    ssh ${USER}@${device} << ENDSSH
        # Create directory
        sudo mkdir -p /opt/seer
        sudo chown \$USER:\$USER /opt/seer
        
        # Clone repository
        if [ ! -d "firewall" ]; then
            git clone ${REPO_URL}
        else
            cd firewall && git pull && cd ..
        fi
        
        # Install
        cd firewall
        sudo ./install.sh
ENDSSH
    
    echo "✓ Deployment to $device complete"
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "All deployments complete!"
```

Usage:
```bash
chmod +x deploy-multiple.sh
./deploy-multiple.sh
```

---

## Updating Existing Installation

### Using Update Script

```bash
# SSH into device
ssh admin@<device-ip>

# Navigate to repository
cd firewall

# Pull latest changes
git pull origin main

# Run update script
sudo ./update.sh
```

### Manual Update

```bash
# Stop service
sudo systemctl stop seer-firewall.service

# Update files
cd firewall
git pull
sudo cp api.py /opt/seer/
sudo cp database.sql /opt/seer/
sudo cp nftables.conf /etc/nftables.conf

# Restart service
sudo systemctl restart seer-firewall.service
```

---

## Pre-Deployment Checklist

Before deploying to production devices:

- [ ] Test installation on development/test device
- [ ] Verify API responds correctly
- [ ] Check firewall rules are loading properly
- [ ] Backup existing configurations
- [ ] Document any custom network settings
- [ ] Ensure git repository is accessible (or package is ready)
- [ ] Test from expected client networks

---

## Post-Deployment Verification

After installing on each device:

```bash
# 1. Check service is running
sudo systemctl status seer-firewall.service

# 2. Verify API responds
curl http://localhost:5000/api/status

# 3. Check firewall rules loaded
sudo nft list ruleset | head -20

# 4. View service logs
sudo journalctl -u seer-firewall.service -n 20
```

---

## Rollback Procedure

If deployment fails or needs to be reverted:

### Using Uninstaller

```bash
cd firewall
sudo ./uninstall.sh
```

### Manual Rollback

```bash
# Stop and remove service
sudo systemctl stop seer-firewall.service
sudo systemctl disable seer-firewall.service
sudo rm /etc/systemd/system/seer-firewall.service
sudo systemctl daemon-reload

# Remove installation
sudo rm -rf /opt/seer

# Restore nftables config (if backed up)
sudo cp /etc/nftables.conf.backup /etc/nftables.conf
sudo systemctl restart nftables
```

---

## Troubleshooting Deployment Issues

### SSH Connection Fails
```bash
# Test SSH connectivity
ssh admin@<device-ip> 'echo "SSH works"'

# Check network connectivity
ping <device-ip>

# Use verbose mode
ssh -v admin@<device-ip>
```

### Git Clone Fails
```bash
# Check internet connectivity on device
ssh admin@<device-ip> 'ping -c 3 github.com'

# Try HTTPS vs SSH URL
git clone https://github.com/lyncsolutionsph/firewall
```

### Installation Script Fails
```bash
# Check logs
sudo journalctl -xe

# Verify permissions on /opt/seer
ls -la /opt/seer

# Check Python environment
/opt/seer/venv/bin/python3 --version

# Run installer with verbose output
sudo bash -x ./install.sh
```

### Service Won't Start
```bash
# Check detailed logs
sudo journalctl -u seer-firewall.service -n 100 --no-pager

# Test API manually
cd /opt/seer
source venv/bin/activate
python3 api.py

# Check port availability
sudo ss -tulpn | grep 5000
```

### Firewall Rules Not Loading
```bash
# Check nftables service
sudo systemctl status nftables

# Verify config syntax
sudo nft -c -f /etc/nftables.conf

# View current ruleset
sudo nft list ruleset
```

---

## Maintenance & Monitoring

### Regular Maintenance

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Update SEER Firewall
cd firewall && git pull && sudo ./update.sh

# Check service health
sudo systemctl status seer-firewall.service

# Review logs for errors
sudo journalctl -u seer-firewall.service --since "7 days ago" | grep -i error
```

### Monitoring Commands

```bash
# Check service status
systemctl is-active seer-firewall.service

# API health check
curl -s http://localhost:5000/api/status

# View active connections
sudo ss -tunap | grep :5000

# Firewall statistics
sudo nft list ruleset -a
```

---

## Quick Reference

| Task | Command |
|------|---------|
| Clone repository | `git clone https://github.com/lyncsolutionsph/firewall` |
| Install | `cd firewall && sudo ./install.sh` |
| Update | `cd firewall && git pull && sudo ./update.sh` |
| Uninstall | `cd firewall && sudo ./uninstall.sh` |
| Check status | `sudo systemctl status seer-firewall.service` |
| View logs | `sudo journalctl -u seer-firewall.service -f` |
| Restart | `sudo systemctl restart seer-firewall.service` |
| Test API | `curl http://localhost:5000/api/status` |

---

## Best Practices

1. **Test First**: Always test on a non-production device first
2. **Backup Configs**: Keep backups of custom configurations
3. **Document Changes**: Track what was modified and when
4. **Monitor Logs**: Regularly check logs for errors
5. **Keep Updated**: Pull latest changes from repository regularly
6. **Network Isolation**: Ensure API is not exposed to untrusted networks

---

**End of Deployment Guide**
