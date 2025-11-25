# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0] - 2025-11-25

### 🎉 Major Release - Enhanced Reliability & Error Handling

#### Added
- **Logging System** - Consistent `log_info()`, `log_warn()`, `log_error()` functions
- **Helper Functions** - `_exists()` function for portable command checking
- **Network Timeouts** - All curl commands now have `--max-time` protection (5-30 seconds)
- **SSH Validation** - `sshd -t` configuration validation before restart
- **Input Validation** - Comprehensive menu input validation with clear prompts
- **Error Recovery** - Automatic backup and restore on critical failures
- **Better Error Messages** - Actionable, user-friendly error feedback
- **Comprehensive Documentation** - IMPROVEMENTS.md and enhanced README

#### Fixed
- **Critical Bugs**
  - Fixed undefined `remove_old_ssh_conf()` function (was called but never defined)
  - Fixed missing `_exists()` helper function (was called at line 747)
  - Fixed double `done` statement syntax error (lines 1070-1071)
  - Fixed malformed `ask_bbr_version()` function structure
  - Fixed unclosed string literals in help text (line 861)

- **Code Quality**
  - Removed hardcoded GitHub IPs (lines 384-385)
  - Fixed SSH config indentation issues
  - Improved sed usage with proper escaping
  - Better variable scoping and local declarations

#### Changed
- **complete_update()** - Added error checking for apt-get operations
- **set_timezone()** - Improved JSON parsing, added timeout, better error handling
- **optimize_ssh_configuration()** - Added validation, backup verification
- **ask_bbr_version()** - Better error handling, improved input validation (0-4)
- **speedtestcli()** - Added UI, better error handling, timeout protection
- **benchmark()** - Added input validation, improved error messages
- **Main Menu** - Better formatting, clearer input prompts, improved error handling

#### Improved
- Error handling on all critical operations
- User experience with clearer feedback
- Code maintainability and consistency
- Security with SSH validation
- Network reliability with timeouts
- Backup and restore procedures

#### Removed
- Hardcoded GitHub IP addresses
- Unsafe sed patterns
- Redundant code sections

### 🔒 Security Improvements
- SSH configuration validation before restart
- Better command execution with proper quoting
- Improved file operation safety
- Automatic backup verification

### 📊 Performance
- Early exit on errors prevents wasted time
- Better resource usage with proper error handling
- Prevents hung processes with timeouts

### 📚 Documentation
- Comprehensive README.md with badges and examples
- Detailed IMPROVEMENTS.md with all changes
- Better inline code comments
- Troubleshooting guide added

---

## [2.0] - Previous Release

### Features
- One-click VPS optimization
- Step-by-step optimization mode
- TCP BBR congestion control
- Multiple queuing algorithms
- Swap file management
- SSH configuration
- DNS optimization
- Timezone configuration
- GRUB tuning
- Speedtest integration
- Benchmark testing
- Iranian mirror support

### Known Issues (Fixed in v3.0)
- Missing function definitions
- Syntax errors
- Insufficient error handling
- No network timeouts
- Limited input validation

---

## [1.0] - Initial Release

### Features
- Basic VPS optimization
- System update and upgrade
- Package installation
- Sysctl configuration
- SSH hardening

---

## Upgrade Guide

### From v2.0 to v3.0

**Recommended:** Fresh installation
```bash
apt install curl -y && bash <(curl -s https://raw.githubusercontent.com/opiran-club/VPS-Optimizer/main/optimizer.sh --ipv4)
```

**Or update existing installation:**
```bash
cd /path/to/VPS-Optimizer
git pull origin main
chmod +x optimizer.sh
sudo ./optimizer.sh
```

### Breaking Changes
None - Full backward compatibility maintained

### Migration Notes
- All backups are preserved
- Previous configurations remain intact
- New error handling is transparent to users

---

## Testing

### Tested On
- ✅ Ubuntu 20.04 LTS
- ✅ Ubuntu 22.04 LTS
- ✅ Debian 11 (Bullseye)
- ✅ Debian 12 (Bookworm)
- ✅ OpenVZ containers
- ✅ KVM virtual machines

### Repository
- **GitHub:** https://github.com/ThilinaM99/VPS-One-Click-Optimizer
- **Original:** https://github.com/opiran-club/VPS-Optimizer

### Test Coverage
- ✅ All menu options
- ✅ Error conditions
- ✅ Network failures
- ✅ Permission issues
- ✅ Missing dependencies
- ✅ Invalid user input

---

## Known Limitations

### Current
- Debian-based systems only (Ubuntu, Debian)
- Requires root access
- No dry-run mode
- No configuration file support

### Planned for Future Releases
- CentOS/RHEL support
- Dry-run mode
- Configuration file support
- Automated rollback capability
- Web-based UI

---

## Contributors

- **Original Author:** OPIran Club
- **v3.0 Improvements:** Community Contributors
- **Testing & Feedback:** All users

---

## Support

For issues, questions, or suggestions:
- 📧 GitHub Issues: [Report here](https://github.com/opiran-club/VPS-Optimizer/issues)
- 💬 Telegram: [@OPIranCluB](https://t.me/opiranclub)
- 📺 YouTube: [@opiran-institute](https://www.youtube.com/@opiran-institute)

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Last Updated:** November 25, 2025  
**Current Version:** 3.0  
**Status:** ✅ Production Ready
