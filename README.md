# SEER Firewall Management System

## Overview
The SEER Firewall system provides a centralized firewall management interface using:
- **nftables** - Modern Linux firewall framework
- **Python Flask API** - Backend service for rule management
- **SQLite database** - Persistent rule state storage (optional, for future enhancements)
- **Systemd service** - Automatic startup and service management

## Quick Installation

### Automated Install (Recommended)

```bash
# 1. Clone the repository
git clone https://github.com/lyncsolutionsph/firewall

# 2. Navigate to directory
cd firewall

# 3. Make installer executable and run it
chmod +x install.sh
sudo bash install.sh
```

The installation script will automatically:
- Copy required files to `/opt/seer`
- Install system dependencies (python3-venv)
- Set up Python virtual environment
- Install Flask and Flask-CORS
- Configure systemd service
- Start the firewall API service

### Manual Installation Steps

If you prefer to install manually:

**Step 1:** Create installation directory
```bash
sudo mkdir -p /opt/seer
sudo chown $USER:$USER /opt/seer
```

**Step 2:** Clone repository and make scripts executable
```bash
git clone https://github.com/lyncsolutionsph/firewall
cd firewall
chmod +x *.sh
```

**Step 3:** Copy files
```bash
sudo cp database.sql /opt/seer/
sudo cp api.py /opt/seer/
sudo cp nftables.conf /etc/nftables.conf
sudo cp nftables.conf /etc/nftables.conf.template
sudo cp seer-firewall.service /etc/systemd/system/
```

**Step 4:** Setup Python environment
```bash
cd /opt/seer
sudo apt install python3-venv -y
python3 -m venv venv
source venv/bin/activate
pip install flask flask-cors
deactivate
```

**Step 5:** Enable and start service
```bash
sudo systemctl daemon-reload
sudo systemctl enable seer-firewall.service
sudo systemctl start seer-firewall.service
```

**Step 6:** Verify installation
```bash
sudo systemctl status seer-firewall.service
```

## System Architecture

### How It Works

The SEER Firewall runs as a systemd service that:
1. Starts automatically on boot
2. Runs Python Flask API on port 5000
3. Manages nftables firewall rules
4. Provides REST API for rule management

### Service Management

```bash
# Check service status
sudo systemctl status seer-firewall.service

# View live logs
sudo journalctl -u seer-firewall.service -f

# Restart service
sudo systemctl restart seer-firewall.service

# Stop service
sudo systemctl stop seer-firewall.service
```

## File Locations

| File | Location | Purpose |
|------|----------|---------|
| API Backend | `/opt/seer/api.py` | Flask API service |
| Database Schema | `/opt/seer/database.sql` | SQLite schema |
| Python Environment | `/opt/seer/venv/` | Virtual environment |
| Firewall Config | `/etc/nftables.conf` | Active nftables rules |
| Config Template | `/etc/nftables.conf.template` | Backup template |
| Service File | `/etc/systemd/system/seer-firewall.service` | Systemd unit |

## API Endpoints

The Flask API provides the following endpoints:

### Status Check
```bash
GET http://localhost:5000/api/status
```

### Get All Rules
```bash
GET http://localhost:5000/api/rules
```

### Toggle Rule
```bash
POST http://localhost:5000/api/rules/{id}/toggle
Content-Type: application/json

{
  "field": "rule_enabled",
  "value": 1
}
```

## Testing the Installation

### Test API Connectivity
```bash
# Check API status
curl http://localhost:5000/api/status

# Test API response
curl http://localhost:5000/api/rules
```

### Verify nftables Configuration
```bash
# View active firewall rules
sudo nft list ruleset

# Check specific chain
sudo nft list chain inet filter input
```

## Maintenance

### Updating the System

```bash
# Navigate to repository
cd firewall

# Pull latest changes
git pull origin main

# Run update script
sudo ./update.sh
```

### Uninstalling

```bash
# Run uninstall script
cd firewall
sudo ./uninstall.sh
```

## Useful Commands

```bash
# Service management
sudo systemctl status seer-firewall.service    # Check status
sudo systemctl restart seer-firewall.service   # Restart service
sudo systemctl stop seer-firewall.service      # Stop service
sudo systemctl start seer-firewall.service     # Start service

# View logs
sudo journalctl -u seer-firewall.service -f    # Follow logs
sudo journalctl -u seer-firewall.service -n 50 # Last 50 lines

# Firewall management
sudo nft list ruleset                          # View all rules
sudo systemctl status nftables                 # Check nftables status
sudo systemctl restart nftables                # Reload firewall
```

## Troubleshooting

### Service Won't Start
```bash
# Check detailed logs
sudo journalctl -u seer-firewall.service -n 100 --no-pager

# Test API manually
cd /opt/seer
source venv/bin/activate
python3 api.py
```

### Port Already in Use
```bash
# Check what's using port 5000
sudo netstat -tulpn | grep 5000
sudo lsof -i :5000
```

### Python Dependencies Missing
```bash
cd /opt/seer
source venv/bin/activate
pip install flask flask-cors
deactivate
```

## Security Notes

- The API runs on port 5000 (localhost by default)
- Ensure firewall rules are properly configured to restrict access
- Keep the system updated with `sudo ./update.sh`
- Regular backup of `/opt/seer/` directory recommended

## Support

For issues, questions, or contributions:
- GitHub Repository: https://github.com/lyncsolutionsph/firewall
- Check existing documentation in the repository
- Review logs: `sudo journalctl -u seer-firewall.service -f`
