-- SEER Firewall Database Schema
-- SQLite database for persistent firewall rule configuration

-- Policy Rules Table
CREATE TABLE IF NOT EXISTS policy_rules (
    id INTEGER PRIMARY KEY,
    policy TEXT NOT NULL,
    source TEXT NOT NULL,
    destination TEXT NOT NULL,
    type TEXT NOT NULL,
    protocol TEXT NOT NULL,
    action TEXT NOT NULL,
    nat_enabled INTEGER DEFAULT 0, -- 0 = OFF, 1 = ON
    rule_enabled INTEGER DEFAULT 1, -- 0 = DISABLED, 1 = ENABLED
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

-- Blacklist Table
CREATE TABLE IF NOT EXISTS blacklist (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ip_address TEXT UNIQUE NOT NULL,
    reason TEXT,
    added_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME
);

-- Audit Log Table
CREATE TABLE IF NOT EXISTS audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    action TEXT NOT NULL,
    rule_id INTEGER,
    details TEXT,
    user TEXT DEFAULT 'admin',
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Custom Rules Table (user-defined firewall rules)
CREATE TABLE IF NOT EXISTS custom_rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    port INTEGER NOT NULL,
    protocol TEXT NOT NULL, -- TCP, UDP, Both
    usage TEXT DEFAULT 'Custom',
    action TEXT DEFAULT 'ACCEPT', -- ACCEPT or DROP
    access_from TEXT, -- Display string: "LAN + Tailscale + WAN"
    access_lan INTEGER DEFAULT 0, -- 0 = No, 1 = Yes
    access_tailnet INTEGER DEFAULT 0, -- 0 = No, 1 = Yes
    access_wan INTEGER DEFAULT 0, -- 0 = No, 1 = Yes
    enabled INTEGER DEFAULT 1, -- 0 = DISABLED, 1 = ENABLED
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_policy_rules_enabled ON policy_rules(rule_enabled);
CREATE INDEX IF NOT EXISTS idx_blacklist_ip ON blacklist(ip_address);
CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_log(timestamp);
CREATE INDEX IF NOT EXISTS idx_custom_rules_enabled ON custom_rules(enabled);
CREATE INDEX IF NOT EXISTS idx_custom_rules_port ON custom_rules(port);
