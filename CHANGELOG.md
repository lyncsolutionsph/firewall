# Changelog

All notable changes to the SEER Firewall Management System.

## [2.0.0] - 2025-12-05

### Changed
- Reorganized repository structure with `firewall/` subdirectory for core files
- Installation script uses `mv` instead of `cp` for better performance
- Automatic cleanup of cloned repository after installation
- Reduced installation script from 479 to 128 lines (73% smaller)
- Streamlined installation process

### Added
- `version.txt` for version tracking
- Automatic repository cleanup after installation
- Better error handling

### Removed
- Obsolete web interface files
- Test and migration scripts
- Redundant documentation

### Fixed
- Shell script execute permissions
- Dynamic path handling with `$SCRIPT_DIR`

## [1.0.0] - 2024

Initial release with basic firewall management system.
