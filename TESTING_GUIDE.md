# Testing Guide - Custom Rules Persistence

## Quick Start Testing

### 1. Deploy and Setup
```bash
# On your Raspberry Pi
cd /home/admin

# Run migration (if not done yet)
python3 migrate_custom_rules.py

# Add sample test data
python3 add_sample_rules.py

# Restart API to load changes
sudo systemctl restart seer-firewall
```

### 2. Open UI
Navigate to: `http://192.168.50.1:1880/seer-firewall/`

You should see:
- **Policy Ruleset** table with 3 services (SSH, SEER Web Interface, NAT)
- **Custom Ruleset** table with 5 sample rules

## Sample Rules Added

| Name | Port | Protocol | Access | Status | Description |
|------|------|----------|--------|--------|-------------|
| Web Server | 8080 | TCP | LAN + Tailscale | ✅ Enabled | Custom web application |
| Database Server | 5432 | TCP | LAN | ✅ Enabled | PostgreSQL database |
| API Gateway | 3000 | TCP | LAN + Tailscale + WAN | ❌ Disabled | REST API endpoint |
| Game Server | 25565 | TCP | WAN | ✅ Enabled | Minecraft server |
| VPN Service | 1194 | Both | WAN | ❌ Disabled | OpenVPN server |

## Test Scenarios

### Test 1: View Custom Rules ✓
**Expected:** All 5 sample rules appear in Custom Ruleset table

**Verify:**
```bash
# Check database
sqlite3 /home/admin/.node-red/seer_database/seer.db "SELECT id, name, port, enabled FROM custom_rules;"

# Should show:
# 1|Web Server|8080|1
# 2|Database Server|5432|1
# 3|API Gateway|3000|0
# 4|Game Server|25565|1
# 5|VPN Service|1194|0
```

### Test 2: Toggle Rule ON/OFF ✓
**Steps:**
1. Find "API Gateway" (currently OFF)
2. Click toggle button
3. Confirm in modal
4. Verify toast notification appears

**Verify:**
```bash
# Check database
sqlite3 /home/admin/.node-red/seer_database/seer.db \
  "SELECT name, enabled FROM custom_rules WHERE name='API Gateway';"

# Should show: API Gateway|1 (if you turned it ON)

# Check nftables
sudo nft list ruleset | grep "3000"

# Should show rule if enabled
```

### Test 3: Select Multiple Rules ✓
**Steps:**
1. Click checkbox for "Web Server"
2. Click checkbox for "Database Server"
3. Verify both are checked

**Expected:** Row highlights, checkboxes marked

### Test 4: Select All ✓
**Steps:**
1. Click checkbox in table header (next to "Service Description")
2. All rule checkboxes should become checked
3. Click again to uncheck all

**Expected:** All checkboxes toggle together

### Test 5: Delete Single Rule ✓
**Steps:**
1. Check "VPN Service" checkbox only
2. Click "Delete Selected" button
3. Confirm in modal
4. Verify rule disappears

**Verify:**
```bash
# Check database
sqlite3 /home/admin/.node-red/seer_database/seer.db \
  "SELECT COUNT(*) FROM custom_rules WHERE name='VPN Service';"

# Should show: 0
```

### Test 6: Delete Multiple Rules ✓
**Steps:**
1. Check "Web Server" and "Game Server"
2. Click "Delete Selected"
3. Modal should show both names
4. Confirm deletion

**Expected:** Both rules removed from table and database

### Test 7: Add New Custom Rule ✓
**Steps:**
1. Click "+ Add Custom Rule" button
2. Fill form:
   - **Service Name:** Test Service
   - **Description:** Testing custom rules
   - **Port:** 9999
   - **Protocol:** TCP
   - **Usage:** Application
   - **Access:** LAN + Tailscale (checked)
3. Click "Add Rule"

**Verify:**
```bash
# Check database
sqlite3 /home/admin/.node-red/seer_database/seer.db \
  "SELECT * FROM custom_rules WHERE port=9999;"

# Check nftables
sudo nft list ruleset | grep "9999"

# Should show rules for port 9999
```

### Test 8: PERSISTENCE - THE BIG TEST! ✓
**Steps:**
1. Note current custom rules (take screenshot or count)
2. Reboot: `sudo reboot`
3. Wait for system to restart (2-3 minutes)
4. Open UI again
5. Check Custom Ruleset table

**Expected:** All custom rules still present after reboot!

**Verify:**
```bash
# After reboot, check API logs
journalctl -u seer-firewall -n 50 | grep "Restored"

# Should see: "✓ Restored X custom firewall rules from database"

# Check database (should match pre-reboot)
sqlite3 /home/admin/.node-red/seer_database/seer.db \
  "SELECT id, name, port, enabled FROM custom_rules;"

# Check nftables (enabled rules should be restored)
sudo nft list ruleset | grep "Custom Rule"
```

### Test 9: Form Validation ✓
**Steps:**
1. Click "+ Add Custom Rule"
2. Leave "Service Name" empty
3. Click "Add Rule"

**Expected:** Error toast: "Please enter a service name"

**Try:**
- Empty port → "Please enter a port number"
- No access selected → "Please select at least one access source"

### Test 10: Network Connectivity Test ✓
**Steps:**
1. Add rule: Port 8888, TCP, LAN access
2. From LAN device, run: `telnet 192.168.50.1 8888`
3. Should connect (or timeout if no service listening)
4. Toggle rule OFF
5. Try again: `telnet 192.168.50.1 8888`

**Expected:** Connection blocked when rule is OFF

## Manual Testing Checklist

- [ ] UI loads without errors
- [ ] Sample rules appear in table (5 rules)
- [ ] Checkboxes are visible and clickable
- [ ] Select All checkbox works
- [ ] Toggle buttons change state (ON/OFF)
- [ ] Toggle shows confirmation modal
- [ ] Toast notifications appear
- [ ] Add rule modal opens and closes
- [ ] Form validation works
- [ ] New rules save successfully
- [ ] Delete shows confirmation with rule names
- [ ] Multiple delete works
- [ ] Rules persist after reboot
- [ ] nftables rules created correctly
- [ ] API responds within 5 seconds
- [ ] No console errors in browser (F12)

## API Testing (Command Line)

```bash
# Test 1: Get all custom rules
curl http://localhost:5000/api/custom-rules

# Test 2: Add a rule
curl -X POST http://localhost:5000/api/custom-rules \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test API",
    "description": "Testing via curl",
    "port": 7777,
    "protocol": "TCP",
    "usage": "Custom",
    "accessFrom": "LAN",
    "accessLan": true,
    "accessTailnet": false,
    "accessWan": false
  }'

# Test 3: Toggle rule (replace {id} with actual ID)
curl -X POST http://localhost:5000/api/custom-rules/1/toggle \
  -H "Content-Type: application/json" \
  -d '{"enabled": false}'

# Test 4: Delete rule (replace {id} with actual ID)
curl -X DELETE http://localhost:5000/api/custom-rules/1
```

## Troubleshooting Tests

### Test Failed: Rules Don't Appear
```bash
# Check API is running
sudo systemctl status seer-firewall

# Check API logs
journalctl -u seer-firewall -f

# Check database
sqlite3 /home/admin/.node-red/seer_database/seer.db \
  "SELECT * FROM custom_rules;"

# Test API endpoint
curl http://localhost:5000/api/custom-rules
```

### Test Failed: Rules Don't Persist After Reboot
```bash
# Check if restore function runs on startup
journalctl -u seer-firewall | grep "Restored"

# If not found, api.py might not be calling restore_custom_rules()
# Check api.py has this code in if __name__ == '__main__':
#   restore_custom_rules()
```

### Test Failed: Checkboxes Don't Work
```bash
# Check browser console (F12)
# Look for JavaScript errors

# Verify select-all-custom element exists
# Open browser console and run:
document.getElementById('select-all-custom')
# Should return the checkbox element
```

### Test Failed: Can't Add Rules (500 Error)
```bash
# Check table exists
sqlite3 /home/admin/.node-red/seer_database/seer.db \
  ".tables"

# Should include: custom_rules

# If missing, run migration
python3 migrate_custom_rules.py
```

## Performance Testing

```bash
# Test 1: Load time with 100 rules
# Add 100 rules via API script
for i in {1..100}; do
  curl -X POST http://localhost:5000/api/custom-rules \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"Rule$i\",\"port\":$((8000+i)),\"protocol\":\"TCP\",\"accessLan\":true}"
done

# Measure UI load time (should be < 3 seconds)

# Test 2: Database query time
time sqlite3 /home/admin/.node-red/seer_database/seer.db \
  "SELECT * FROM custom_rules;"

# Should be < 100ms
```

## Expected Results Summary

| Test | Expected Result | Pass/Fail |
|------|----------------|-----------|
| View Rules | 5 sample rules visible | ☐ |
| Toggle Rule | State changes, nftables updated | ☐ |
| Select Multiple | Checkboxes work | ☐ |
| Select All | All rules selected | ☐ |
| Delete Single | Rule removed | ☐ |
| Delete Multiple | All selected removed | ☐ |
| Add New Rule | Rule appears, nftables updated | ☐ |
| **Persistence** | **Rules survive reboot** | ☐ |
| Form Validation | Errors show for invalid input | ☐ |
| Network Block | Port blocked when rule OFF | ☐ |

## Success Criteria

✅ **All tests pass**  
✅ **Custom rules persist after reboot**  
✅ **No console errors**  
✅ **API responds < 5 seconds**  
✅ **Database operations < 100ms**  
✅ **nftables rules apply correctly**

## Clean Up Test Data

```bash
# Remove all custom rules
sqlite3 /home/admin/.node-red/seer_database/seer.db \
  "DELETE FROM custom_rules;"

# Restart API
sudo systemctl restart seer-firewall

# Verify empty
curl http://localhost:5000/api/custom-rules
# Should return: {"success":true,"rules":[]}
```

## View Sample Rules

```bash
# Quick view of what will be added
python3 add_sample_rules.py show
```

---

**Ready to Test?**

```bash
# One command to set everything up:
python3 migrate_custom_rules.py && \
python3 add_sample_rules.py && \
sudo systemctl restart seer-firewall && \
echo "✓ Ready! Open http://192.168.50.1:1880/seer-firewall/"
```
