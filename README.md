# SEER Firewall - Installation & Setup

## Overview
The SEER Firewall system uses:
- **SQLite database** to store rule states (persists after reboot)
- **Python Flask API** to handle toggle operations
- **nftables** for actual firewall rules
- **Node-RED UI** for the web interface

## Installation Steps

### 1. Install Dependencies
```bash
sudo apt update
sudo apt install -y python3 python3-pip sqlite3 nftables
sudo pip3 install flask flask-cors
```

### 2. Create Application Directory
```bash
sudo mkdir -p /opt/seer
sudo chown $USER:$USER /opt/seer
```

### 3. Copy Files
```bash
# Copy all files to /opt/seer/
sudo cp database.sql /opt/seer/
sudo cp api.py /opt/seer/
sudo cp nftables.conf /etc/nftables.conf
sudo cp nftables.conf /etc/nftables.conf.template
```

### 4. Initialize Database
```bash
cd /opt/seer
sqlite3 firewall.db < database.sql
```

### 5. Set Permissions
```bash
sudo chown root:root /etc/nftables.conf
sudo chmod 644 /etc/nftables.conf
sudo chown root:root /opt/seer/firewall.db
sudo chmod 644 /opt/seer/firewall.db
```

### 6. Install Systemd Service
```bash
sudo cp seer-firewall.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable seer-firewall.service
sudo systemctl start seer-firewall.service
```

### 7. Check Service Status
```bash
sudo systemctl status seer-firewall.service
```

### 8. Enable nftables on Boot
```bash
sudo systemctl enable nftables.service
sudo systemctl start nftables.service
```

## How It Works

### Toggle a Rule
1. User clicks ON/OFF toggle in web interface
2. JavaScript sends POST request to API: `/api/rules/{id}/toggle`
3. API updates SQLite database (rule_enabled or nat_enabled field)
4. API regenerates nftables.conf from database
5. API reloads nftables with: `nft -f /etc/nftables.conf`
6. Changes persist after reboot

### Rule State Persistence
- **SQLite database** stores: `rule_enabled` (0=disabled, 1=enabled)
- On system boot:
  1. Systemd starts `seer-firewall.service`
  2. API reads database
  3. Generates nftables.conf with only enabled rules
  4. Applies configuration

### Database Schema
```sql
policy_rules
  - id: Rule ID
  - policy: Rule name
  - rule_enabled: 0 (disabled) or 1 (enabled)
  - nat_enabled: 0 (NAT off) or 1 (NAT on)
  - updated_at: Last change timestamp
```

## API Endpoints

### Get All Rules
```
GET http://localhost:5000/api/rules
```

### Toggle Rule
```
POST http://localhost:5000/api/rules/{id}/toggle
Body: {
  "field": "rule_enabled",  // or "nat_enabled"
  "value": 1  // 0 = OFF, 1 = ON
}
```

### Get Blacklist
```
GET http://localhost:5000/api/blacklist
```

### Add to Blacklist
```
POST http://localhost:5000/api/blacklist
Body: {
  "ip_address": "192.168.1.100",
  "reason": "Suspicious activity"
}
```

### Remove from Blacklist
```
DELETE http://localhost:5000/api/blacklist/{id}
```

### Get Status
```
GET http://localhost:5000/api/status
```

### Get Audit Log
```
GET http://localhost:5000/api/audit?limit=100
```

## Testing

### Test API Manually
```bash
# Get all rules
curl http://localhost:5000/api/rules

# Disable rule #9 (Node-RED Access)
curl -X POST http://localhost:5000/api/rules/9/toggle \
  -H "Content-Type: application/json" \
  -d '{"field":"rule_enabled","value":0}'

# Enable rule #9
curl -X POST http://localhost:5000/api/rules/9/toggle \
  -H "Content-Type: application/json" \
  -d '{"field":"rule_enabled","value":1}'
```

### Verify nftables Rules
```bash
# Check active rules
sudo nft list ruleset

# Check if specific port is blocked
sudo nft list chain inet filter input | grep 1880
```

### Check Database
```bash
sqlite3 /opt/seer/firewall.db "SELECT id, policy, rule_enabled FROM policy_rules;"
```

## Logs

### API Logs
```bash
sudo journalctl -u seer-firewall.service -f
```

### nftables Logs
```bash
sudo journalctl -k | grep NFT
```

### Audit Log (Database)
```bash
sqlite3 /opt/seer/firewall.db "SELECT * FROM audit_log ORDER BY timestamp DESC LIMIT 20;"
```

## Important Notes

1. **Critical Rules**: Some rules (DHCP, Loopback, Established Connections) should NEVER be disabled or you'll lose network connectivity

2. **Reboot Persistence**: Rule states are saved in SQLite, so disabled rules stay disabled after reboot

3. **Security**: The API runs on port 5000 - ensure it's only accessible from LAN/Tailnet

4. **Backup**: Regular backup your database:
   ```bash
   sqlite3 /opt/seer/firewall.db ".backup /opt/seer/backups/firewall_$(date +%Y%m%d).db"
   ```

## Troubleshooting

### API Not Starting
```bash
# Check Python errors
sudo journalctl -u seer-firewall.service -n 50

# Test manually
cd /opt/seer
python3 api.py
```

### Toggle Not Working
1. Check API is running: `curl http://localhost:5000/api/status`
2. Check browser console for JavaScript errors
3. Verify CORS is enabled in api.py

### Rules Not Applied After Reboot
1. Check database: `sqlite3 /opt/seer/firewall.db "SELECT * FROM policy_rules;"`
2. Check nftables.conf was regenerated
3. Check nftables service: `sudo systemctl status nftables`

## Next Steps

After installation:
1. Access web interface via Node-RED
2. Test toggling a non-critical rule (like Node-RED Access)
3. Verify rule is disabled: `sudo nft list ruleset | grep 1880`
4. Check database: `sqlite3 /opt/seer/firewall.db "SELECT rule_enabled FROM policy_rules WHERE id=9;"`
5. Reboot and verify rule stays disabled
