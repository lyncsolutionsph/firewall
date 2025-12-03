#!/usr/bin/env python3
"""
Add 'action' column to existing custom_rules table
Run this if you get error: "table custom_rules has no column named action"
"""

import sqlite3
import sys

DATABASE = '/home/admin/.node-red/seer_database/seer.db'

def add_action_column():
    """Add action column to custom_rules table"""
    try:
        conn = sqlite3.connect(DATABASE)
        cursor = conn.cursor()
        
        # Check if custom_rules table exists
        cursor.execute("""
            SELECT name FROM sqlite_master 
            WHERE type='table' AND name='custom_rules'
        """)
        
        if not cursor.fetchone():
            print("✗ custom_rules table does not exist!")
            print("  Run migrate_custom_rules.py first")
            conn.close()
            return False
        
        # Check if action column already exists
        cursor.execute("PRAGMA table_info(custom_rules)")
        columns = [col[1] for col in cursor.fetchall()]
        
        if 'action' in columns:
            print("✓ 'action' column already exists in custom_rules table")
            conn.close()
            return True
        
        # Add action column
        print("Adding 'action' column to custom_rules table...")
        cursor.execute("""
            ALTER TABLE custom_rules 
            ADD COLUMN action TEXT DEFAULT 'ACCEPT'
        """)
        
        # Update existing rules to have ACCEPT action
        cursor.execute("""
            UPDATE custom_rules 
            SET action = 'ACCEPT' 
            WHERE action IS NULL
        """)
        
        conn.commit()
        print("✓ Successfully added 'action' column!")
        print("  All existing rules set to 'ACCEPT' (Allow)")
        
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
    print("Add 'action' Column to custom_rules Table")
    print("=" * 50)
    print(f"Database: {DATABASE}")
    print()
    
    if add_action_column():
        print()
        print("=" * 50)
        print("Migration completed successfully!")
        print("=" * 50)
        print()
        print("Next steps:")
        print("1. Restart Flask API:")
        print("   sudo systemctl restart seer-firewall")
        print()
        print("2. Try adding a custom rule again")
        print("   You can now choose ACCEPT or DROP!")
        sys.exit(0)
    else:
        print()
        print("Migration failed. Please check the error messages above.")
        sys.exit(1)
