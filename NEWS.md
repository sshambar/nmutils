Overview of changes in nmutils-20250418
=======================================

- Added config command to 08-ipv6-prefix and 09-ddns with tests
- general-functions 1.8.0 adds nmg::print_env, nmg::unset_env, 
    nmg::get_config and nmg::load_comment
- ddns-functions 1.6.0 adds nmddns_get_config and nmddns_get_globals
- Added tests for new functions
- `08-ipv6-prefix` now has config command
- `09-ddns` now has help and config command

Overview of changes in nmutils-20241216
=======================================

- SELinux patch for dhclient pid file
- Correct make dist

Overview of changes in nmutils-20241215
=======================================

***BREAKING CHANGE:***
 - package installs now look for config in /etc/nmutils by default
   (/etc/nmutils/conf still used for 'make install' installs)

Other significant changes:
- Rewrite of `08-ipv6-prefix` adding:
  - `dhcpcd` dhcp client support
    - adds RFC6603 prefix exclude support
    - supports RA DNS assignments
 - ipv6.method=ignore full ipv6 management
    - required for dhcpcd client support
    - `rdisc6` may be needed for default maintenance
    - `resolvectl` or `resolvconf` needed for DNS handling
  - many config changes may now be made with `nmcli device reapply`
  - dhcp client monitoring to recover from lockups/bugs in client
  - DNS server routes added
  - Source-based prefix routes supporting multiple WANs without
    firewall rules
  - Unreachable routes for unassigned prefix subnets
  - Configurable route metrics (DNS routes or SADR routes)
  - Gateway monitoring and active restoration
  - Subnet deprecation when gateway lost (after short timeout), WAN
    down, or via external trigger (see "deprecate" command)
  - DAD detection of generated addresses, and address retry
  - fallback dhclient-script support if requested
  - monitor and dhcp client daemons managed with systemctl
  - `08-ipv6-prefix` may now be run directly, commands include
    - `deprecate` for creating/releasing multiple independent
      prefix deprecation "locks"
    - `status` to display current WAN/LAN stats
    - `help` to display full documentation
  - extensive tests for all core features
- Addition of `96-interface-action` to complement `dispatcher_action`
  - systemctl action independent of state-file creation/removal
  - is-enable may be ignored (great for startup after iface up)
  - actions enabled by config file presence (no creating dispatchers)
  with simpler config and additional features.
- `meson` patch and install (supporting relocation). Package 
  installation can be easily masked by non-package install for
  temporary overrides of source/config for testing/evaluation.
- Makefile supporing:
  - `make help` to explain targets
  - `make install` and `make uninstall`
  - `make dist` for source tar
  - `make tarball` for patched install tar
  - `make srpm` and `make rpm` for package creation
- Test suite expanded to include:
  - `nmcli-mock` supporting state modification (updates)
  - `dummy-mock` generalized to support most "fake binaries" via symlinks
  - `ip-mock` added support for link, route and monitor.  Much better
    ipv6 prefix support
  - Many tests for added functionlity (now over 1400!)
    - new functions
	- `dhcpcd` client
	- ipv6.method=ignore
- general-functions updated with many new functions
  - general hashing
  - ip monitor support for watching address/route changes
  - ipv6 prefix compression
  - ip route functions
  - many new tests
  - re-licensed LGPLv3
