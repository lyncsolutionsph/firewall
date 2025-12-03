#!/usr/bin/env python3
"""
Add Sample Custom Rules for Testing
Inserts test data into the custom_rules table
"""

import sqlite3
import sys

DATABASE = '/home/admin/.node-red/seer_database/seer.db'

SAMPLE_RULES = [
    {
        'name': 'Web Server',
        'description': 'Custom web application server',
        'port': 8080,
        'protocol': 'TCP',
        'usage': 'Web Service',
        'action': 'ACCEPT',
        'access_from': 'LAN + Tailscale',
        'access_lan': 1,
        'access_tailnet': 1,
        'access_wan': 0,
        'enabled': 1
    },
    {
        'name': 'Database Server',
        'description': 'PostgreSQL database for internal tools',
        'port': 5432,
        'protocol': 'TCP',
        'usage': 'Database',
        'action': 'ACCEPT',
        'access_from': 'LAN',
        'access_lan': 1,
        'access_tailnet': 0,
        'access_wan': 0,
        'enabled': 1
    },
    {
        'name': 'Block HTTPS',
        'description': 'Block HTTPS traffic from WAN',
        'port': 443,
        'protocol': 'TCP',
        'usage': 'Security',
        'action': 'DROP',
        'access_from': 'WAN',
        'access_lan': 0,
        'access_tailnet': 0,
        'access_wan': 1,
        'enabled': 1
    },
    {
        'name': 'Game Server',
        'description': 'Minecraft server for friends',
        'port': 25565,
        'protocol': 'TCP',
        'usage': 'Application',
        'action': 'ACCEPT',
        'access_from': 'WAN',
        'access_lan': 0,
        'access_tailnet': 0,
        'access_wan': 1,
        'enabled': 1
    },
    {
        'name': 'Block Telnet',
        'description': 'Block insecure telnet protocol',
        'port': 23,
        'protocol': 'TCP',
        'usage': 'Security',
        'action': 'DROP',
        'access_from': 'LAN + Tailscale + WAN',
        'access_lan': 1,
        'access_tailnet': 1,
        'access_wan': 1,
        'enabled': 1
    }
]

def add_sample_rules():
    """Add sample custom rules to database"""
    try:
        conn = sqlite3.connect(DATABASE)
        cursor = conn.cursor()
        
        # Check if table exists
        cursor.execute("""
            SELECT name FROM sqlite_master 
            WHERE type='table' AND name='custom_rules'
        """)
        
        if not cursor.fetchone():
            print("✗ custom_rules table does not exist!")
            print("  Run migrate_custom_rules.py first")
            conn.close()
            return False
        
        # Check for existing sample rules
        cursor.execute("SELECT COUNT(*) FROM custom_rules")
        existing_count = cursor.fetchone()[0]
        
        if existing_count > 0:
            print(f"⚠ Database already has {existing_count} custom rule(s)")
            response = input("  Do you want to add more samples? (y/n): ")
            if response.lower() != 'y':
                print("Cancelled.")
                conn.close()
                return False
        
        # Insert sample rules
        print("\nAdding sample custom rules...")
        for i, rule in enumerate(SAMPLE_RULES, 1):
            cursor.execute("""
                INSERT INTO custom_rules (
                    name, description, port, protocol, usage, action,
                    access_from, access_lan, access_tailnet, access_wan, enabled
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                rule['name'],
                rule['description'],
                rule['port'],
                rule['protocol'],
                rule['usage'],
                rule['action'],
                rule['access_from'],
                rule['access_lan'],
                rule['access_tailnet'],
                rule['access_wan'],
                rule['enabled']
            ))
            
            enabled_text = "ENABLED" if rule['enabled'] else "DISABLED"
            print(f"  {i}. {rule['name']:<20} Port {rule['port']:<6} {enabled_text:<10} ({rule['access_from']})")
        
        conn.commit()
        print(f"\n✓ Added {len(SAMPLE_RULES)} sample rules successfully!")
        
        # Show total count
        cursor.execute("SELECT COUNT(*) FROM custom_rules")
        total_count = cursor.fetchone()[0]
        print(f"  Total custom rules in database: {total_count}")
        
        conn.close()
        return True
        
    except sqlite3.Error as e:
        print(f"✗ Database error: {e}")
        return False
    except Exception as e:
        print(f"✗ Error: {e}")
        return False

def show_existing_rules():
    """Display all custom rules in database"""
    try:
        conn = sqlite3.connect(DATABASE)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT id, name, port, protocol, access_from, enabled 
            FROM custom_rules 
            ORDER BY id
        """)
        
        rules = cursor.fetchall()
        
        if not rules:
            print("No custom rules found in database.")
            conn.close()
            return
        
        print("\n" + "=" * 80)
        print("EXISTING CUSTOM RULES")
        print("=" * 80)
        print(f"{'ID':<5} {'Name':<25} {'Port':<8} {'Protocol':<10} {'Access':<20} {'Status':<10}")
        print("-" * 80)
        
        for rule in rules:
            rule_id, name, port, protocol, access_from, enabled = rule
            status = "ENABLED" if enabled else "DISABLED"
            print(f"{rule_id:<5} {name:<25} {port:<8} {protocol:<10} {access_from:<20} {status:<10}")
        
        print("-" * 80)
        print(f"Total: {len(rules)} rule(s)")
        print("=" * 80)
        
        conn.close()
        
    except Exception as e:
        print(f"Error showing rules: {e}")

if __name__ == '__main__':
    print("=" * 50)
    print("SEER Firewall - Add Sample Custom Rules")
    print("=" * 50)
    print(f"Database: {DATABASE}")
    print()
    
    # Check if user wants to see existing rules first
    if len(sys.argv) > 1 and sys.argv[1] == 'show':
        show_existing_rules()
        sys.exit(0)
    
    if add_sample_rules():
        print("\n" + "=" * 50)
        print("Next Steps:")
        print("=" * 50)
        print("1. Restart Flask API:")
        print("   sudo systemctl restart seer-firewall")
        print()
        print("2. Open SEER Firewall UI:")
        print("   http://192.168.50.1:1880/seer-firewall/")
        print()
        print("3. You should see 5 sample custom rules in the table")
        print()
        print("4. Test functionality:")
        print("   • Toggle rules ON/OFF")
        print("   • Select multiple rules with checkboxes")
        print("   • Delete selected rules")
        print("   • Add new custom rules")
        print()
        print("To view existing rules: python3 add_sample_rules.py show")
        sys.exit(0)
    else:
        print("\nFailed to add sample rules.")
        sys.exit(1)
