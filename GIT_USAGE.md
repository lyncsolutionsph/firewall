# Git Repository Management

This document explains how to use git with the SEER Firewall Management System.

## Initial Setup

If you haven't initialized a git repository yet:

```bash
# Initialize repository
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit - SEER Firewall v1.0.0"

# Add remote (replace with your repository URL)
git remote add origin https://github.com/yourusername/seer-firewall.git

# Push to remote
git push -u origin main
```

## Using Git with Installer

### Fresh Installation with Git Check

When running `install.sh` on a device that has the git repository:

```bash
sudo ./install.sh
```

The installer will:
1. Detect if it's a git repository
2. Check if remote updates are available
3. Offer to pull latest changes
4. Continue with installation

### Updating Existing Installation

Use the dedicated update script:

```bash
# Pull latest changes and update installation
sudo ./update.sh
```

This script will:
1. ✅ Check git repository status
2. ✅ Show available updates
3. ✅ Pull latest changes
4. ✅ Backup database
5. ✅ Stop service
6. ✅ Update files
7. ✅ Update Python packages
8. ✅ Restart service

## Common Git Workflows

### Making Changes

```bash
# Make your changes to files
nano api.py

# Check what changed
git status
git diff

# Stage changes
git add api.py

# Commit changes
git commit -m "Fix: Updated API endpoint for custom rules"

# Push to remote
git push origin main
```

### Deploying Updates to Devices

```bash
# On each device with existing installation
cd /path/to/seer-firewall-repo
sudo ./update.sh
```

The update script handles everything automatically.

### Checking for Updates (Manual)

```bash
# Fetch latest changes
git fetch origin

# Check if updates available
git status

# View what changed
git log HEAD..origin/main --oneline

# Pull updates
git pull origin main
```

## Version Management

### Tagging Releases

```bash
# Create a version tag
git tag -a v1.0.1 -m "Version 1.0.1 - Bug fixes"

# Push tag to remote
git push origin v1.0.1

# List all tags
git tag -l
```

### Checking Out Specific Version

```bash
# List available versions
git tag -l

# Checkout specific version
git checkout v1.0.0

# Return to latest
git checkout main
```

## Branching Strategy

### Development Branch

```bash
# Create development branch
git checkout -b develop

# Make changes and commit
git add .
git commit -m "Feature: Add new rule type"

# Push development branch
git push origin develop

# Merge to main when ready
git checkout main
git merge develop
git push origin main
```

### Feature Branches

```bash
# Create feature branch
git checkout -b feature/custom-schedules

# Work on feature
# ... make changes ...

# Commit and push
git add .
git commit -m "Add scheduling feature"
git push origin feature/custom-schedules

# Merge via pull request or locally
git checkout main
git merge feature/custom-schedules
```

## Git Configuration

### Recommended `.gitignore`

Already included in the repository:
- Python cache files
- Database files (*.db)
- Log files
- Backup files
- Distribution packages
- IDE files

### Global Git Settings

```bash
# Set your identity
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Set default editor
git config --global core.editor nano

# Enable color output
git config --global color.ui auto
```

## Multi-Device Deployment with Git

### Scenario: Update 5 Raspberry Pi devices

```bash
# On your development machine
git add .
git commit -m "Update: Improved firewall rules"
git push origin main

# On each Raspberry Pi device
ssh admin@device1.local
cd /path/to/seer-firewall
sudo ./update.sh
exit

# Repeat for other devices or automate:
for device in device1 device2 device3 device4 device5; do
    ssh admin@${device}.local "cd /path/to/seer-firewall && sudo ./update.sh"
done
```

## Rollback Procedure

If an update causes issues:

```bash
# Check commit history
git log --oneline

# Rollback to previous version
git checkout <previous-commit-hash>

# Or rollback to specific tag
git checkout v1.0.0

# Re-run installer or update script
sudo ./install.sh

# Return to latest when fixed
git checkout main
```

## Troubleshooting

### Merge Conflicts

```bash
# If pull fails due to local changes
git stash                    # Save local changes
git pull origin main         # Pull updates
git stash pop               # Restore local changes
# Resolve conflicts manually
git add .
git commit -m "Merge conflicts resolved"
```

### Detached HEAD State

```bash
# If you checked out a specific commit
git checkout main           # Return to main branch
```

### Reset to Remote State

```bash
# Discard all local changes (CAUTION!)
git fetch origin
git reset --hard origin/main
```

## Best Practices

1. **Always commit before updates**
   ```bash
   git add .
   git commit -m "Save current state"
   ```

2. **Test on development device first**
   - Pull updates on dev device
   - Test thoroughly
   - Then deploy to production devices

3. **Use meaningful commit messages**
   ```bash
   git commit -m "Fix: Custom rules not persisting after reboot"
   git commit -m "Feature: Add support for IPv6 rules"
   git commit -m "Update: Improved error handling in API"
   ```

4. **Tag stable releases**
   ```bash
   git tag -a v1.0.1 -m "Stable release with bug fixes"
   git push origin v1.0.1
   ```

5. **Regular backups**
   - Database backups are created automatically by update.sh
   - Consider backing up the entire repository

## Automated Update Script

Create `auto-update-all.sh` for bulk updates:

```bash
#!/bin/bash

DEVICES=(
    "192.168.50.10"
    "192.168.50.11"
    "192.168.50.12"
)

REPO_PATH="/home/admin/seer-firewall"

for device in "${DEVICES[@]}"; do
    echo "═══════════════════════════════════════"
    echo "Updating device: $device"
    echo "═══════════════════════════════════════"
    
    ssh admin@${device} << EOF
        cd ${REPO_PATH}
        git fetch origin
        if [ \$(git rev-list --count HEAD..origin/main) -gt 0 ]; then
            echo "Updates available, installing..."
            sudo ./update.sh <<< $'y\ny'
        else
            echo "Already up to date"
        fi
EOF
    
    echo ""
done

echo "All devices updated!"
```

## Quick Reference

| Command | Description |
|---------|-------------|
| `git status` | Check repository status |
| `git pull origin main` | Pull latest changes |
| `git log --oneline` | View commit history |
| `sudo ./update.sh` | Update installation from git |
| `git tag -l` | List version tags |
| `git checkout v1.0.0` | Switch to specific version |
| `git diff` | View uncommitted changes |

---

**For more information, see:**
- `DEPLOYMENT.md` - Deployment procedures
- `README.md` - General documentation
- `update.sh` - Update script source code
