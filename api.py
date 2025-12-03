#!/usr/bin/env python3
"""
SEER Firewall API Backend
Handles database operations and nftables rule management
"""

import sqlite3
import subprocess
import json
from datetime import datetime
from flask import Flask, jsonify, request
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

DATABASE = '/home/admin/.node-red/seer_database/seer.db'
NFTABLES_CONF = '/etc/nftables.conf'

def get_db():
    """Get database connection"""
    conn = sqlite3.connect(DATABASE)
    conn.row_factory = sqlite3.Row
    return conn

def execute_nft_command(command):
    """Execute nftables command"""
    try:
        result = subprocess.run(
            ['nft'] + command.split(),
            capture_output=True,
            text=True,
            check=True
        )
        return {'success': True, 'output': result.stdout}
    except subprocess.CalledProcessError as e:
        return {'success': False, 'error': e.stderr}

def reload_nftables():
    """Reload nftables configuration"""
    try:
        # Use 'nft -f' with flush table to reload cleanly
        # This flushes and reloads the specific table, not the entire ruleset
        subprocess.run(['systemctl', 'reload', 'nftables'], check=True)
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error reloading nftables: {e}")
        # Fallback to direct reload
        try:
            subprocess.run(['nft', '-f', NFTABLES_CONF], check=True)
            return True
        except:
            return False

def generate_nftables_config():
    """Generate nftables.conf from database by commenting out disabled rules and adding DROP rules"""
    conn = get_db()
    rules = conn.execute('SELECT * FROM policy_rules ORDER BY id').fetchall()
    conn.close()
    
    # Create a mapping of rule policies to their enabled status and track disabled services
    rule_status = {}
    disabled_tcp_ports = []
    disabled_icmp = False
    nat_enabled = True  # Track NAT/masquerade status
    
    for rule in rules:
        rule_dict = dict(rule)
        policy = rule_dict['policy']
        rule_status[policy] = {
            'enabled': rule_dict['rule_enabled'] == 1,
            'nat_enabled': rule_dict['nat_enabled'] == 1
        }
        
        # Track NAT status for LAN to WAN Forward rule (ID 16)
        if rule_dict['id'] == 16:
            nat_enabled = rule_dict['nat_enabled'] == 1
        
        # Track disabled services to insert DROP rules before LAN accept
        if rule_dict['rule_enabled'] == 0:
            if 'Temporal' in policy:
                disabled_tcp_ports.append('$TEMPORAL_PORT')
            elif 'Node-RED' in policy:
                disabled_tcp_ports.append('$NODERED_PORT')
            elif 'FastAPI' in policy:
                disabled_tcp_ports.append('$FASTAPI_PORT')
            elif 'SSH' in policy:
                disabled_tcp_ports.append('$SSH_PORT')
            elif 'DNS' in policy:
                disabled_tcp_ports.append('$DNS_PORT')
            elif 'ICMP' in policy:
                disabled_icmp = True
    
    # Read current config
    try:
        with open(NFTABLES_CONF, 'r') as f:
            lines = f.readlines()
    except FileNotFoundError:
        return False
    
    # Process lines with look-ahead
    new_lines = []
    disable_next_rule = False  # Flag to disable the next actual rule line
    enable_next_rule = False  # Flag to enable the next [DISABLED] rule line
    
    for i, line in enumerate(lines):
        stripped = line.strip()
        
        # Check if this line is a comment that identifies a rule
        rule_identified = None
        
        # Match BOTH Remote and LAN rules for the same service
        if '# Allowing Node-Red' in line or '# Allow Node-Red' in line:
            rule_identified = 'Node-RED Access'
        elif '# Allow Temporal Policy' in line:  # Matches both Remote and LAN
            rule_identified = 'Temporal Policy'
        elif '# Allow FastAPI' in line:  # Matches both Remote and LAN
            rule_identified = 'FastAPI'
        elif '# SSH with rate limiting' in line:
            rule_identified = 'SSH Access'
        elif '# ICMP handling' in line:
            rule_identified = 'ICMP Rate Limit'
        elif '# DNS queries to firewall' in line:
            rule_identified = 'DNS Queries'
        elif '# LAN access' in line and 'Allow' not in line:
            rule_identified = 'LAN Access'
        elif '# LAN → WAN' in line or '# LAN -> WAN' in line:
            rule_identified = 'LAN to WAN Forward'
        elif '# Masquerade LAN traffic' in line:
            rule_identified = 'NAT_MASQUERADE'  # Special handling for NAT
        
        # If we identified a rule, check its status and set flags
        if rule_identified and rule_identified in rule_status:
            status = rule_status[rule_identified]
            disable_next_rule = not status['enabled']
            enable_next_rule = status['enabled']
        
        # Special handling for NAT masquerade based on nat_enabled
        if rule_identified == 'NAT_MASQUERADE':
            disable_next_rule = not nat_enabled
            enable_next_rule = nat_enabled
        
        # Check if this is an actual firewall rule line
        is_actual_rule = stripped and not stripped.startswith('#') and (
            'accept' in stripped or 'drop' in stripped or 'reject' in stripped or 'masquerade' in stripped
        )
        
        is_disabled_rule = '[DISABLED]' in line
        
        # Case 1: Active rule that needs to be disabled
        if disable_next_rule and is_actual_rule:
            # Comment must be at start of line for nftables to ignore it
            indent = line[:len(line) - len(line.lstrip())]
            new_lines.append(f'#{indent}[DISABLED] {stripped}\n')
            disable_next_rule = False
            continue
        
        # Case 2: Disabled rule that needs to be enabled
        if enable_next_rule and is_disabled_rule:
            # Line format: #          [DISABLED] tcp dport...
            # Need to extract the original rule after [DISABLED]
            if '[DISABLED]' in line:
                # Get everything after [DISABLED] 
                parts = line.split('[DISABLED]', 1)
                if len(parts) == 2:
                    # Extract the actual rule after [DISABLED]
                    actual_rule = parts[1].lstrip()
                    # Get the indentation from the part between # and [DISABLED]
                    indent = parts[0].replace('#', '', 1)
                    new_lines.append(f'{indent}{actual_rule}')
                    enable_next_rule = False
                    continue
        
        # Insert DROP rules for disabled services BEFORE the general LAN accept
        if '# LAN access' in line and 'Allow' not in line and (disabled_tcp_ports or disabled_icmp):
            indent = '\t\t'
            
            # Add TCP port DROP rules for BOTH Tailscale and LAN
            for port in disabled_tcp_ports:
                new_lines.append(f'{indent}# [AUTO-DROP] Disabled TCP port {port}\n')
                new_lines.append(f'{indent}tcp dport {port} ip saddr $TAILNET counter drop\n')
                new_lines.append(f'{indent}iifname $LAN tcp dport {port} counter drop\n')
            
            # Add ICMP DROP rule
            if disabled_icmp:
                new_lines.append(f'{indent}# [AUTO-DROP] Disabled ICMP (ping)\n')
                new_lines.append(f'{indent}iifname $LAN ip protocol icmp counter drop\n')
                new_lines.append(f'{indent}iifname $LAN ip6 nexthdr icmpv6 counter drop\n')
            
            if disabled_tcp_ports or disabled_icmp:
                new_lines.append('\n')
        
        # Case 3: Keep line as-is
        new_lines.append(line)
        
        # Reset flags after processing a non-comment, non-empty line
        if is_actual_rule or is_disabled_rule:
            disable_next_rule = False
            enable_next_rule = False
    
    # Remove old AUTO-DROP rules on next pass (clean up before inserting new ones)
    final_lines = []
    skip_count = 0
    for line in new_lines:
        if '[AUTO-DROP]' in line:
            # Skip this comment line and determine how many rule lines to skip
            if 'ICMP' in line:
                skip_count = 2  # Skip 2 lines (IPv4 and IPv6 ICMP drops)
            else:
                skip_count = 2  # Skip 2 lines (Tailscale DROP + LAN DROP)
            continue
        if skip_count > 0:
            skip_count -= 1
            continue
        final_lines.append(line)
    
    # Write updated config
    try:
        with open(NFTABLES_CONF, 'w') as f:
            f.writelines(final_lines)
        return True
    except Exception as e:
        print(f"Error writing config: {e}")
        return False

# API Endpoints

@app.route('/api/rules', methods=['GET'])
def get_rules():
    """Get all policy rules"""
    conn = get_db()
    rules = conn.execute('SELECT * FROM policy_rules ORDER BY id').fetchall()
    conn.close()
    
    return jsonify({
        'success': True,
        'rules': [dict(rule) for rule in rules]
    })

@app.route('/api/rules/<int:rule_id>/toggle', methods=['POST'])
def toggle_rule(rule_id):
    """Toggle rule enabled/disabled state"""
    data = request.json
    field = data.get('field')  # 'rule_enabled' or 'nat_enabled'
    value = data.get('value')  # 0 or 1
    
    if field not in ['rule_enabled', 'nat_enabled']:
        return jsonify({'error': 'Invalid field'}), 400
    
    # Prevent disabling the API itself (rule_id 11 = FastAPI)
    if rule_id == 11 and field == 'rule_enabled' and value == 0:
        return jsonify({'error': 'Cannot disable API access - you would lock yourself out!'}), 400
    
    conn = get_db()
    cursor = conn.cursor()
    
    # Update database
    cursor.execute(
        f'UPDATE policy_rules SET {field} = ?, updated_at = ? WHERE id = ?',
        (value, datetime.now().isoformat(), rule_id)
    )
    
    # Log the change
    action = f"{'Enabled' if value else 'Disabled'} {field.replace('_', ' ')}"
    cursor.execute(
        'INSERT INTO firewall_audit_log (action, rule_id, details) VALUES (?, ?, ?)',
        (action, rule_id, json.dumps(data))
    )
    
    conn.commit()
    conn.close()
    
    # Regenerate and reload nftables config
    print(f"[DEBUG] Regenerating nftables config for rule {rule_id}, {field}={value}")
    config_success = generate_nftables_config()
    if not config_success:
        return jsonify({'error': 'Failed to generate config'}), 500
    
    print(f"[DEBUG] Reloading nftables...")
    reload_success = reload_nftables()
    if not reload_success:
        return jsonify({'error': 'Failed to reload firewall'}), 500
    
    # If disabling a rule, also drop existing connections for that port
    if field == 'rule_enabled' and value == 0:
        print(f"[DEBUG] Dropping existing connections for disabled rule {rule_id}")
        try:
            # Get rule details to find the port
            conn = get_db()
            rule = conn.execute('SELECT * FROM policy_rules WHERE id = ?', (rule_id,)).fetchone()
            conn.close()
            
            if rule:
                rule_dict = dict(rule)
                policy = rule_dict.get('policy', '')
                
                # Drop connections based on policy type
                if 'Temporal' in policy:
                    subprocess.run(['conntrack', '-D', '-p', 'tcp', '--dport', '1889'], 
                                 capture_output=True, check=False)
                elif 'Node-RED' in policy:
                    subprocess.run(['conntrack', '-D', '-p', 'tcp', '--dport', '1880'], 
                                 capture_output=True, check=False)
                elif 'FastAPI' in policy:
                    subprocess.run(['conntrack', '-D', '-p', 'tcp', '--dport', '8000'], 
                                 capture_output=True, check=False)
        except Exception as e:
            print(f"[WARNING] Could not drop connections: {e}")
    
    return jsonify({
        'success': True,
        'rule_id': rule_id,
        'field': field,
        'value': value
    })

@app.route('/api/blacklist', methods=['GET'])
def get_blacklist():
    """Get blacklisted IPs"""
    conn = get_db()
    ips = conn.execute('SELECT * FROM firewall_blacklist ORDER BY added_at DESC').fetchall()
    conn.close()
    
    return jsonify([dict(ip) for ip in ips])

@app.route('/api/blacklist', methods=['POST'])
def add_blacklist():
    """Add IP to blacklist"""
    data = request.json
    ip_address = data.get('ip_address')
    reason = data.get('reason', 'Manual block')
    
    conn = get_db()
    cursor = conn.cursor()
    
    try:
        cursor.execute(
            'INSERT INTO firewall_blacklist (ip_address, reason) VALUES (?, ?)',
            (ip_address, reason)
        )
        
        # Add to nftables blacklist set
        ip_version = 'blacklist_v6' if ':' in ip_address else 'blacklist_v4'
        execute_nft_command(f'add element inet filter {ip_version} {{ {ip_address} }}')
        
        cursor.execute(
            'INSERT INTO firewall_audit_log (action, details) VALUES (?, ?)',
            ('Blacklist IP', json.dumps({'ip': ip_address, 'reason': reason}))
        )
        
        conn.commit()
        conn.close()
        
        return jsonify({'success': True, 'ip_address': ip_address})
    except sqlite3.IntegrityError:
        return jsonify({'error': 'IP already blacklisted'}), 400

@app.route('/api/blacklist/<int:ip_id>', methods=['DELETE'])
def remove_blacklist(ip_id):
    """Remove IP from blacklist"""
    conn = get_db()
    cursor = conn.cursor()
    
    # Get IP address
    ip_row = cursor.execute('SELECT ip_address FROM firewall_blacklist WHERE id = ?', (ip_id,)).fetchone()
    
    if not ip_row:
        return jsonify({'error': 'IP not found'}), 404
    
    ip_address = ip_row['ip_address']
    
    # Remove from database
    cursor.execute('DELETE FROM firewall_blacklist WHERE id = ?', (ip_id,))
    
    # Remove from nftables
    ip_version = 'blacklist_v6' if ':' in ip_address else 'blacklist_v4'
    execute_nft_command(f'delete element inet filter {ip_version} {{ {ip_address} }}')
    
    cursor.execute(
        'INSERT INTO firewall_audit_log (action, details) VALUES (?, ?)',
        ('Remove from blacklist', json.dumps({'ip': ip_address}))
    )
    
    conn.commit()
    conn.close()
    
    return jsonify({'success': True})

@app.route('/api/status', methods=['GET'])
def get_status():
    """Get firewall status"""
    conn = get_db()
    
    enabled_rules = conn.execute('SELECT COUNT(*) as count FROM policy_rules WHERE rule_enabled = 1').fetchone()['count']
    blacklist_count = conn.execute('SELECT COUNT(*) as count FROM firewall_blacklist').fetchone()['count']
    
    conn.close()
    
    return jsonify({
        'enabled_rules': enabled_rules,
        'blacklist_count': blacklist_count,
        'firewall_active': True
    })

@app.route('/api/audit', methods=['GET'])
def get_audit_log():
    """Get audit log"""
    limit = request.args.get('limit', 100, type=int)
    
    conn = get_db()
    logs = conn.execute(
        'SELECT * FROM firewall_audit_log ORDER BY timestamp DESC LIMIT ?',
        (limit,)
    ).fetchall()
    conn.close()
    
    return jsonify([dict(log) for log in logs])

# ==================== CUSTOM RULES API ====================

@app.route('/api/custom-rules', methods=['GET'])
def get_custom_rules():
    """Get all custom rules"""
    try:
        conn = get_db()
        rules = conn.execute(
            'SELECT * FROM custom_rules ORDER BY id ASC'
        ).fetchall()
        conn.close()
        
        return jsonify({
            'success': True,
            'rules': [dict(rule) for rule in rules]
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/custom-rules', methods=['POST'])
def add_custom_rule():
    """Add a new custom rule"""
    try:
        data = request.json
        
        # Validate required fields
        if not data.get('name') or not data.get('port'):
            return jsonify({'success': False, 'error': 'Name and port are required'}), 400
        
        conn = get_db()
        cursor = conn.cursor()
        
        # Insert new rule
        cursor.execute('''
            INSERT INTO custom_rules (
                name, description, port, protocol, usage, action,
                access_from, access_lan, access_tailnet, access_wan, enabled
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            data['name'],
            data.get('description', ''),
            int(data['port']),
            data.get('protocol', 'TCP'),
            data.get('usage', 'Custom'),
            data.get('action', 'ACCEPT'),
            data.get('accessFrom', 'LAN'),
            1 if data.get('accessLan') else 0,
            1 if data.get('accessTailnet') else 0,
            1 if data.get('accessWan') else 0,
            1  # Enabled by default
        ))
        
        rule_id = cursor.lastrowid
        conn.commit()
        
        # Apply nftables rules
        apply_custom_rule(cursor.lastrowid, data)
        
        conn.close()
        
        return jsonify({
            'success': True,
            'message': 'Custom rule added',
            'rule_id': rule_id
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/custom-rules/<int:rule_id>', methods=['DELETE'])
def delete_custom_rule(rule_id):
    """Delete a custom rule"""
    try:
        conn = get_db()
        
        # Get rule details before deleting
        rule = conn.execute(
            'SELECT * FROM custom_rules WHERE id = ?', (rule_id,)
        ).fetchone()
        
        if not rule:
            conn.close()
            return jsonify({'success': False, 'error': 'Rule not found'}), 404
        
        # Delete from database
        conn.execute('DELETE FROM custom_rules WHERE id = ?', (rule_id,))
        conn.commit()
        
        # Remove nftables rules
        remove_custom_rule(dict(rule))
        
        conn.close()
        
        return jsonify({
            'success': True,
            'message': 'Custom rule deleted'
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/custom-rules/<int:rule_id>/toggle', methods=['POST'])
def toggle_custom_rule(rule_id):
    """Toggle a custom rule on/off"""
    try:
        data = request.json
        enabled = data.get('enabled', True)
        
        conn = get_db()
        
        # Get rule details
        rule = conn.execute(
            'SELECT * FROM custom_rules WHERE id = ?', (rule_id,)
        ).fetchone()
        
        if not rule:
            conn.close()
            return jsonify({'success': False, 'error': 'Rule not found'}), 404
        
        # Update enabled state
        conn.execute(
            'UPDATE custom_rules SET enabled = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
            (1 if enabled else 0, rule_id)
        )
        conn.commit()
        
        # Apply or remove nftables rules based on state
        rule_dict = dict(rule)
        if enabled:
            apply_custom_rule(rule_id, rule_dict)
        else:
            remove_custom_rule(rule_dict)
        
        conn.close()
        
        return jsonify({
            'success': True,
            'message': f'Custom rule {"enabled" if enabled else "disabled"}'
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

def apply_custom_rule(rule_id, rule_data):
    """Apply custom rule to nftables"""
    try:
        port = rule_data.get('port') or rule_data.get('port')
        protocol = (rule_data.get('protocol') or rule_data.get('protocol', 'TCP')).lower()
        action = (rule_data.get('action') or rule_data.get('action', 'ACCEPT')).lower()
        
        # Determine protocol(s)
        protocols = []
        if protocol == 'both':
            protocols = ['tcp', 'udp']
        else:
            protocols = [protocol]
        
        # Add rules for each access point
        for proto in protocols:
            if rule_data.get('accessLan') or rule_data.get('access_lan'):
                # LAN access - INPUT chain (traffic TO firewall)
                subprocess.run([
                    'nft', 'add', 'rule', 'inet', 'filter', 'input',
                    'iifname', 'br0', proto, 'dport', str(port),
                    'counter', action,
                    'comment', f'"Custom Rule {rule_id}"'
                ], check=False)
                
                # If blocking, also add FORWARD rule (LAN -> Internet)
                if action == 'drop':
                    subprocess.run([
                        'nft', 'add', 'rule', 'inet', 'filter', 'forward',
                        'iifname', 'br0', proto, 'dport', str(port),
                        'counter', 'drop',
                        'comment', f'"Custom Rule {rule_id} Forward"'
                    ], check=False)
                    
                    # Also block in OUTPUT chain (firewall itself)
                    subprocess.run([
                        'nft', 'add', 'rule', 'inet', 'filter', 'output',
                        'oifname', 'eth1', proto, 'dport', str(port),
                        'counter', 'drop',
                        'comment', f'"Custom Rule {rule_id} Output"'
                    ], check=False)
            
            if rule_data.get('accessTailnet') or rule_data.get('access_tailnet'):
                # Tailscale access - INPUT chain
                subprocess.run([
                    'nft', 'add', 'rule', 'inet', 'filter', 'input',
                    proto, 'dport', str(port), 'ip', 'saddr', '100.64.0.0/10',
                    'counter', action,
                    'comment', f'"Custom Rule {rule_id}"'
                ], check=False)
            
            if rule_data.get('accessWan') or rule_data.get('access_wan'):
                # WAN access - INPUT chain (incoming from internet)
                subprocess.run([
                    'nft', 'add', 'rule', 'inet', 'filter', 'input',
                    'iifname', 'eth1', proto, 'dport', str(port),
                    'counter', action,
                    'comment', f'"Custom Rule {rule_id}"'
                ], check=False)
        
        return True
    except Exception as e:
        print(f"Error applying custom rule: {e}")
        return False

def remove_custom_rule(rule_data):
    """Remove custom rule from nftables"""
    try:
        rule_id = rule_data.get('id')
        
        # Delete rules from INPUT chain
        result = subprocess.run([
            'nft', '-a', 'list', 'chain', 'inet', 'filter', 'input'
        ], capture_output=True, text=True)
        
        for line in result.stdout.split('\n'):
            if f'Custom Rule {rule_id}' in line:
                if '# handle' in line:
                    handle = line.split('# handle')[-1].strip()
                    subprocess.run([
                        'nft', 'delete', 'rule', 'inet', 'filter', 'input',
                        'handle', handle
                    ], check=False)
        
        # Delete rules from FORWARD chain
        result = subprocess.run([
            'nft', '-a', 'list', 'chain', 'inet', 'filter', 'forward'
        ], capture_output=True, text=True)
        
        for line in result.stdout.split('\n'):
            if f'Custom Rule {rule_id}' in line:
                if '# handle' in line:
                    handle = line.split('# handle')[-1].strip()
                    subprocess.run([
                        'nft', 'delete', 'rule', 'inet', 'filter', 'forward',
                        'handle', handle
                    ], check=False)
        
        # Delete rules from OUTPUT chain
        result = subprocess.run([
            'nft', '-a', 'list', 'chain', 'inet', 'filter', 'output'
        ], capture_output=True, text=True)
        
        for line in result.stdout.split('\n'):
            if f'Custom Rule {rule_id}' in line:
                if '# handle' in line:
                    handle = line.split('# handle')[-1].strip()
                    subprocess.run([
                        'nft', 'delete', 'rule', 'inet', 'filter', 'output',
                        'handle', handle
                    ], check=False)
        
        return True
    except Exception as e:
        print(f"Error removing custom rule: {e}")
        return False

def restore_custom_rules():
    """Restore all enabled custom rules from database on startup"""
    try:
        conn = get_db()
        rules = conn.execute(
            'SELECT * FROM custom_rules WHERE enabled = 1'
        ).fetchall()
        
        count = 0
        for rule in rules:
            if apply_custom_rule(rule['id'], dict(rule)):
                count += 1
        
        conn.close()
        print(f"✓ Restored {count} custom firewall rules from database")
        return count
    except Exception as e:
        print(f"⚠ Error restoring custom rules: {e}")
        return 0

if __name__ == '__main__':
    print("=" * 50)
    print("SEER Firewall API Starting...")
    print("=" * 50)
    
    # Initialize database
    try:
        conn = get_db()
        with open('database.sql', 'r') as f:
            conn.executescript(f.read())
        conn.close()
        print("✓ Database initialized")
    except FileNotFoundError:
        print("⚠ database.sql not found - assuming database already initialized")
    except Exception as e:
        print(f"⚠ Database initialization warning: {e}")
    
    # Restore custom rules on startup (critical for persistence!)
    print("\nRestoring custom firewall rules...")
    restore_custom_rules()
    
    print("\n" + "=" * 50)
    print("Starting Flask API on 0.0.0.0:5000")
    print("=" * 50 + "\n")
    
    # Run Flask app (debug=False to avoid _ctypes dependency issues)
    app.run(host='0.0.0.0', port=5000, debug=False)
