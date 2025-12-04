# Custom Rules Debugging Guide

## Problem
Custom firewall rules don't persist after page reload and toggle switches don't work properly.

## Changes Made

### 1. Enhanced Logging in `api.py`

#### `apply_custom_rule()` function:
- ✅ Added detailed debug logging for every rule application
- ✅ Changed `subprocess.run()` to capture output and check return codes
- ✅ Fixed access flag checking (properly handles 0/1 values from database)
- ✅ Logs when rules are successfully added or fail
- ✅ Shows exact ports, protocols, and access flags being applied

#### `remove_custom_rule()` function:
- ✅ Added logging for rule removal
- ✅ Counts and reports how many rules were removed
- ✅ Shows handle numbers for debugging

#### `toggle_custom_rule()` endpoint:
- ✅ Logs the toggle operation with rule details
- ✅ Returns error if firewall rule application fails
- ✅ Checks return value from `apply_custom_rule()`

#### `restore_custom_rules()` function:
- ✅ Added prominent startup banner
- ✅ Shows which rules are being restored
- ✅ Reports success/failure for each rule
- ✅ Shows final count of restored rules

### 2. Error Handling Improvements
- Changed from `check=False` to capturing output and checking return codes
- Added `capture_output=True, text=True` to see actual errors
- Added exception traceback printing for debugging

### 3. Data Format Consistency
- Fixed access flag checking to handle both:
  - Frontend (camelCase): `accessLan`, `accessTailnet`, `accessWan`
  - Database (snake_case): `access_lan`, `access_tailnet`, `access_wan`
- Properly converts `0`/`1` integer values to booleans

## How to Debug

### Step 1: Check Service Logs
```bash
sudo journalctl -u seer-firewall -n 100 --no-pager
```

Look for:
- ✓ "RESTORING CUSTOM RULES FROM DATABASE" banner
- ✓ "Found X enabled custom rules"
- ✓ "Applying rule X: port=443, proto=tcp, action=drop"
- ✓ "Added INPUT rule for port 443/tcp"
- ✗ Any error messages

### Step 2: Run Test Script
```bash
sudo python3 /opt/seer-firewall/test_rules.py
```

This will show:
1. **Database contents** - Are rules stored correctly?
2. **nftables rules** - Are rules actually applied?
3. **API response** - Is the API returning rules?

### Step 3: Check Database Directly
```bash
sqlite3 /home/admin/.node-red/seer_database/seer.db "SELECT id, name, port, protocol, action, enabled, access_lan, access_tailnet, access_wan FROM custom_rules;"
```

### Step 4: Check nftables Directly
```bash
sudo nft list ruleset | grep "Custom Rule"
```

### Step 5: Test API Manually
```bash
# Get all rules
curl http://localhost:5000/api/custom-rules

# Toggle a rule (replace 1 with your rule ID)
curl -X POST http://localhost:5000/api/custom-rules/1/toggle \
  -H "Content-Type: application/json" \
  -d '{"enabled": true}'
```

### Step 6: Restart Service and Watch Logs
```bash
# Watch logs in one terminal
sudo journalctl -u seer-firewall -f

# In another terminal, restart service
sudo systemctl restart seer-firewall
```

You should see the "RESTORING CUSTOM RULES" banner and details about each rule being restored.

## Expected Log Output

### Successful Rule Application:
```
Applying rule 1: port=443, proto=tcp, action=drop
  Access: LAN=1, Tailnet=0, WAN=0
✓ Added INPUT rule for port 443/tcp
✓ Successfully applied rule 1
```

### Failed Rule Application:
```
Applying rule 1: port=443, proto=tcp, action=drop
  Access: LAN=1, Tailnet=0, WAN=0
✗ Failed to add INPUT rule: Error: No such file or directory
✗ Error applying rule 1: ...
```

### Successful Restore on Startup:
```
============================================================
RESTORING CUSTOM RULES FROM DATABASE
============================================================
Found 2 enabled custom rules in database

Restoring rule 1: Block Facebook (443)
Applying rule 1: port=443, proto=tcp, action=drop
  Access: LAN=1, Tailnet=0, WAN=0
✓ Added INPUT rule for port 443/tcp
✓ Successfully applied rule 1

Restoring rule 2: SSH Access
Applying rule 2: port=22, proto=tcp, action=accept
  Access: LAN=1, Tailnet=1, WAN=0
✓ Added INPUT rule for port 22/tcp
✓ Added Tailnet INPUT rule for port 22/tcp
✓ Successfully applied rule 2

============================================================
✓ Successfully restored 2/2 custom firewall rules
============================================================
```

## Common Issues and Solutions

### Issue: Rules in database but not loading
**Symptom:** Database shows `enabled=1` but logs show 0 rules restored

**Solution:**
1. Check if service is actually running: `systemctl status seer-firewall`
2. Check if restore function is being called (look for banner in logs)
3. Verify database path is correct: `/home/admin/.node-red/seer_database/seer.db`

### Issue: Toggle doesn't work
**Symptom:** Toggle appears to work in UI but rules aren't applied

**Solution:**
1. Check browser console for JavaScript errors (F12)
2. Check API logs for toggle operation
3. Verify nftables commands are working: `sudo nft --version`
4. Check if user has permission to run nft commands

### Issue: Rules show in nftables but don't block traffic
**Symptom:** `nft list ruleset` shows rules but traffic still passes

**Solution:**
1. Check rule order - earlier ACCEPT rules might override DROP rules
2. Verify interface names: `br0` (LAN), `tailscale0` (Tailnet), `eth1` (WAN)
3. Check if FORWARD chain rules are present for blocking
4. Test with: `sudo nft list chain inet filter input`

### Issue: Frontend doesn't show rules after reload
**Symptom:** Rules exist in database but don't appear in UI

**Solution:**
1. Check browser console for errors
2. Verify API endpoint works: `curl http://localhost:5000/api/custom-rules`
3. Check if API is returning correct JSON format
4. Clear browser cache and reload

## Files Modified
- `api.py` - Enhanced logging, error handling, and data format consistency
- `test_rules.py` - New diagnostic script

## Next Steps
1. Deploy updated `api.py` to the device
2. Restart the service: `sudo systemctl restart seer-firewall`
3. Run test script: `sudo python3 /opt/seer-firewall/test_rules.py`
4. Try adding a rule and check logs: `sudo journalctl -u seer-firewall -f`
5. Try toggling a rule and watch what happens in the logs

## Update Command
```bash
# Copy updated api.py to device
scp api.py admin@<device-ip>:/opt/seer-firewall/

# Copy test script
scp test_rules.py admin@<device-ip>:/opt/seer-firewall/

# SSH into device
ssh admin@<device-ip>

# Restart service
sudo systemctl restart seer-firewall

# Watch logs
sudo journalctl -u seer-firewall -f
```

## Quick Debug Checklist
- [ ] Rules exist in database (`sqlite3 seer.db "SELECT * FROM custom_rules;"`)
- [ ] Rules are `enabled=1` in database
- [ ] Service is running (`systemctl status seer-firewall`)
- [ ] Restore function runs on startup (check logs for banner)
- [ ] Rules appear in nftables (`sudo nft list ruleset | grep "Custom Rule"`)
- [ ] API returns rules (`curl http://localhost:5000/api/custom-rules`)
- [ ] Frontend shows rules (refresh browser, check console)
- [ ] Toggle updates database (check before/after toggle)
- [ ] Toggle applies/removes nftables rules (check with nft)
