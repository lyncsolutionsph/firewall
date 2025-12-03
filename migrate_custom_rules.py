#!/usr/bin/env python3
"""
Database Migration: Add custom_rules table
Run this script to add the custom_rules table to your existing database
"""

import sqlite3
import sys

DATABASE = '/home/admin/.node-red/seer_database/seer.db'

def migrate():
    """Add custom_rules table to existing database"""
    try:
        conn = sqlite3.connect(DATABASE)
        cursor = conn.cursor()
        
        # Check if table already exists
        cursor.execute("""
            SELECT name FROM sqlite_master 
            WHERE type='table' AND name='custom_rules'
        """)
        
        if cursor.fetchone():
            print("✓ custom_rules table already exists")
            conn.close()
            return True
        
        # Create custom_rules table
        print("Creating custom_rules table...")
        cursor.execute("""
            CREATE TABLE custom_rules (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                description TEXT,
                port INTEGER NOT NULL,
                protocol TEXT NOT NULL,
                usage TEXT DEFAULT 'Custom',
                action TEXT DEFAULT 'ACCEPT',
                access_from TEXT,
                access_lan INTEGER DEFAULT 0,
                access_tailnet INTEGER DEFAULT 0,
                access_wan INTEGER DEFAULT 0,
                enabled INTEGER DEFAULT 1,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # Create indexes
        print("Creating indexes...")
        cursor.execute("""
            CREATE INDEX idx_custom_rules_enabled ON custom_rules(enabled)
        """)
        cursor.execute("""
            CREATE INDEX idx_custom_rules_port ON custom_rules(port)
        """)
        
        conn.commit()
        print("✓ Migration completed successfully!")
        print(f"  - custom_rules table created")
        print(f"  - Indexes created")
        
        conn.close()
        return True
        
    except sqlite3.Error as e:
        print(f"✗ Database error: {e}")
        return False
    except Exception as e:
        print(f"✗ Error: {e}")
        return False

if __name__ == '__main__':
    print("=" * 50)
    print("SEER Firewall - Custom Rules Migration")
    print("=" * 50)
    print(f"Database: {DATABASE}")
    print()
    
    if migrate():
        print()
        print("Migration completed successfully!")
        print("You can now use custom firewall rules with persistence.")
        sys.exit(0)
    else:
        print()
        print("Migration failed. Please check the error messages above.")
        sys.exit(1)
