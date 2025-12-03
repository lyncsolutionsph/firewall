#!/bin/bash
# Script to add firewall policy tables to existing SEER database

DB_PATH="/home/admin/.node-red/seer_database/seer.db"

echo "Adding firewall policy tables to existing database: $DB_PATH"

sqlite3 "$DB_PATH" <<'EOF'

-- Policy Rules Table
CREATE TABLE IF NOT EXISTS policy_rules (
    id INTEGER PRIMARY KEY,
    policy TEXT NOT NULL,
    source TEXT NOT NULL,
    destination TEXT NOT NULL,
    type TEXT NOT NULL,
    protocol TEXT NOT NULL,
    action TEXT NOT NULL,
    nat_enabled INTEGER DEFAULT 0,
    rule_enabled INTEGER DEFAULT 1,
    schedule TEXT DEFAULT 'Always',
    usage TEXT DEFAULT 'General',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Insert default rules from nftables.conf
INSERT OR IGNORE INTO policy_rules (id, policy, source, destination, type, protocol, action, nat_enabled, rule_enabled, schedule, usage) VALUES
(1, 'DHCP Traffic', 'LAN/WAN', 'Firewall', 'DHCP', 'UDP', 'ACCEPT', 0, 1, 'Always', 'Critical'),
(2, 'Blacklist Drop', 'Any', 'Any', 'Blacklist', 'All', 'DROP', 0, 1, 'Always', 'Security'),
(3, 'Invalid Packets', 'Any', 'Any', 'Invalid', 'All', 'DROP', 0, 1, 'Always', 'Security'),
(4, 'Loopback', 'Loopback', 'Loopback', 'Local', 'All', 'ACCEPT', 0, 1, 'Always', 'System'),
(5, 'Established Connections', 'Any', 'Any', 'Stateful', 'All', 'ACCEPT', 0, 1, 'Always', 'Critical'),
(6, 'WAN Rate Limit', 'WAN', 'Firewall', 'DoS Protection', 'All', 'RATE-LIMIT', 0, 1, 'Always', 'Security'),
(7, 'SYN Flood Protection', 'WAN', 'Firewall', 'DoS Protection', 'TCP', 'RATE-LIMIT', 0, 1, 'Always', 'Security'),
(8, 'Anti-Spoofing', 'WAN', 'Any', 'RFC Validation', 'All', 'DROP', 0, 1, 'Always', 'Security'),
(9, 'Node-RED Access', 'Tailnet', 'Firewall:1880', 'Service', 'TCP', 'ACCEPT', 0, 1, 'Always', 'Management'),
(10, 'Temporal Policy', 'Tailnet/LAN', 'Firewall:1889', 'Service', 'TCP', 'ACCEPT', 0, 1, 'Always', 'Management'),
(11, 'FastAPI', 'Tailnet/LAN', 'Firewall:5000', 'Service', 'TCP', 'ACCEPT', 0, 1, 'Always', 'API'),
(12, 'LAN Access', 'LAN', 'Firewall', 'Local Network', 'All', 'ACCEPT', 0, 1, 'Always', 'Network'),
(13, 'DNS Queries', 'LAN', 'Firewall:53', 'DNS', 'UDP/TCP', 'ACCEPT', 0, 1, 'Always', 'Network'),
(14, 'ICMP Rate Limit', 'WAN', 'Firewall', 'ICMP', 'ICMP', 'RATE-LIMIT', 0, 1, 'Always', 'Network'),
(15, 'SSH Access', 'Tailnet/WAN', 'Firewall:22', 'SSH', 'TCP', 'RATE-LIMIT', 0, 1, 'Always', 'Management'),
(16, 'LAN to WAN Forward', 'LAN', 'WAN', 'Forward', 'All', 'ACCEPT', 1, 1, 'Always', 'Routing'),
(17, 'Firewall Outbound', 'Firewall', 'WAN', 'Output', 'HTTP/HTTPS/DNS/NTP', 'ACCEPT', 0, 1, 'Always', 'System');

-- Firewall Blacklist Table
CREATE TABLE IF NOT EXISTS firewall_blacklist (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ip_address TEXT UNIQUE NOT NULL,
    reason TEXT,
    added_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME
);

-- Firewall Audit Log Table
CREATE TABLE IF NOT EXISTS firewall_audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    action TEXT NOT NULL,
    rule_id INTEGER,
    details TEXT,
    user TEXT DEFAULT 'admin',
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_policy_rules_enabled ON policy_rules(rule_enabled);
CREATE INDEX IF NOT EXISTS idx_firewall_blacklist_ip ON firewall_blacklist(ip_address);
CREATE INDEX IF NOT EXISTS idx_firewall_audit_timestamp ON firewall_audit_log(timestamp);

EOF

echo "Database tables created successfully!"
echo "Checking tables..."
sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%firewall%' OR name='policy_rules';"
echo ""
echo "Checking policy rules count..."
sqlite3 "$DB_PATH" "SELECT COUNT(*) as count FROM policy_rules;"
