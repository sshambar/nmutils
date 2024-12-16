
Network Manager Utility Scripts
================================
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![License: LGPL v3](https://img.shields.io/badge/License-LGPL_v3-blue.svg)](https://www.gnu.org/licenses/lgpl-3.0)

A collection of BASH based utility scripts and support functions for
use as [NetworkManager](https://networkmanager.dev/) dispatchers.

- [Included Dispatch Scripts](#included-dispatch-scripts)
- [IPv6 Prefix Delegation](#ipv6-prefix-delegation)
- [Setup](#setup)
  - [Installation](#installation)
  - [Configuration](#configuration)
  - [Examples](#examples)
  - [Troubleshooting](#troubleshooting)
- [Support Functions](#support-functions)
  - [Usage](#usage)
- [Documentation](#documentation)
- [SELinux](#selinux)
- [Test Suite](#test-suite)
- [Support](#support)
- [License](#license)

Included Dispatch Scripts
-------------------------

- `08-ipv6-prefix` - **IPv6 Prefix Delegation** <br/>
 The dispatch script will spawn a DHCP client to request an IPv6
 prefix (as well as WAN address), and then assign sub-prefixes from
 the delegated prefix to the LAN interfaces.
 Simple configuration allows fully automatic behavior,
 but can be configured to fully control sub-prefix and address
 creation by interface.  Also supports Dynamic DNS based on prefix
 assignment similar to the interface state DNS script below.

- `09-ddns` - **Dynamic DNS** <br/>
 The dispatch script will use `nsupdate` to set or clear DNS entries
 based on interface state.  Supports address assignment to A or AAAA
 records (with fallback values), and assignment of other records
 (such as CNAME or TXT) individually configurable for each interface.
 
- `95-radvd-gen` - **radvd.conf Generation** <br/>
 The dispatch script will create `/etc/radvd.conf` based on the
 prefixes assigned to interfaces defined in the template
 `/etc/NetworkManager/radvd.conf.templ`

- `96-interface-action` - **Interface action to Service action** <br/>
 Performs systemctl actions on designated services based on interface
 state changes (up, down, pre-down, dhcp-change etc).

IPv6 Prefix Delegation
----------------------

The prefix delegation feature supports multiple address/prefix delegations
from multiple upstream DHCP servers to multiple LAN interfaces.
Features include

- address, prefix and route lifetimes
- DDNS update hooks
- both `dhclient` or `dhcpcd` DHCP client support
- flexible route metrics
- DHCP client monitoring with restart on stalls/failures
- DHCP client command options or config file overrides

WAN (dhcp server) interface supports

- duplicate address detection (with DHCP declines)
- default route monitoring and maintenance using `rdisc6` or linux kernel
- static address, DNS or domain search assignments
- DNS server routes to source WAN (if needed)
- Legacy dhclient-script as option

LAN (delegated sub-prefixes) interfaces support

- per-LAN subnet prefix-size and "subnet #" pre-allocation
- radvd hooks
- prefix delegation size hints
- high-metric unreachable route for unassigned delegated prefixes
- [RFC6603](https://datatracker.ietf.org/doc/html/rfc6603) DHCP Prefix
  Exclude support (requires `dhcpcd`)
- [RFC8678](https://datatracker.ietf.org/doc/html/rfc8678) IPV6
  Multihoming Support:
  - source-based default routes created/maintained for each delegated
    prefix to it source WAN supporting multiple upstream WANs without
	policy-routing
  - NMG_RADVD_TRIGGER assigned to `95-radvd-gen` supports fast router
    deprecation when all routable WANs are offline
  - delegated subnets quickly deprecated using radvd when:
    - WAN down
    - WAN default route lost
    - any external trigger (via script command, see "help")

There are 2 NetworkManager ipv6 connection methods supported

1. **ipv6.method: ignore**
   - supports `dhcpcd` or `dhclient`
   - uses `resolvectl` or `resolvconf` for DNS management
   - WAN addresses/routes have lifetimes
   - when using `dhcpcd` (which requires `rdisc6`):
     - supports DNS via Router Advertisements
     - supports prefix-exclude option
2. **ipv6.method: link-local**
   - addresses and DNS managed with NetworkManager, but require
    "device reapply" (done automatically)
   - requires `rdisc6` for default route management (unless never-default=yes)
   - not compatible with `dhcpcd` (or prefix-exclude)
   - WAN addresses/routes lack lifetimes (addresses cannot be deprecated)

Setup
-----

### Installation

Automated install requires GNU `make` and `meson`.  There are two
independent modes of installation: ***packaged*** or ***development***.  Both
modes can be installed simultaneously, but ***development*** installs
completely mask ***packaged***; both have independent config directories.
Type `make help` for a list of supported "targets"

#### Prerequisites

- [NetworkManager](https://networkmanager.dev/)
- [bash](http://www.gnu.org/software/bash/)
- required command-line tools: `pgrep` `ip`
- optional: `logger` `radvd` `dig` `nsupdate` `flock`
- required for `08-ipv6-prefix`: `nmcli` `systemd` `dhclient` or `dhcpcd`
- optional for `08-ipv6-prefix`: `rdisc6` `resolvectl` `resolvconf`

#### Development Installation

```
$ make
$ sudo make install
```
- Installs to `/etc/nmutils` and `/etc/NetworkManager/dispatcher.d`
- Configuration in `/etc/nmutils/conf`
- Removal: `$ sudo make uninstall`

#### Packaged Installation

```
$ make MESON_FLAGS='-Dpkg=true'
$ sudo make install
```
- Installs to `/usr/share/nmutils` and `/usr/lib/NetworkManager/dispatcher.d`
- Configuration in `/etc/nmutils`
- Removal: `$ sudo make uninstall`

Alternatively, if `rpmbuild` and `mock` are installed
```
$ make rpm
```
will create a source rpm (`make srpm`), then use mock to build rpms
that can be installed on any rpm-based system.

### Configuration

Configuration files should be placed in `/etc/nmutils/conf`
(development) or `/etc/nmutils` (packaged) - henceforth referred to
as "NMCONF"

#### IPv6 Prefix Delegation Configuration

All configuration for prefix delegation is documented in the file
`etc/NetworkManager/dispatcher.d/08-ipv6-prefix`.  Basic prefix
delegation is enabled as simply setting ***ipv6.method*** to
"link-local" or "ignore", and creating a configuration file for
the WAN interface the prefix will be queried on

`NMCONF/ipv6-prefix-<WAN>.conf`
```
WAN_LAN_INTFS="<LAN1> <LAN2>..."
```

Where `<WAN>` and `<LAN#>` should be replaced by the interface names (eth0
etc).

Optional per-LAN configuration can be set in the optional files, eg

`NMCONF/ipv6-prefix-<LAN>-from-<WAN>.conf`
```
# trigger the radvd.conf generation script
NMG_RADVD_TRIGGER="/etc/NetworkManager/dispatcher.d/95-radvd-gen"
```

There are many additional configuraion options.  The script may
be run directly supporting a few additional features
```
# display full documentation, explaining all config options
$ ./08-ipv6-prefix help

# prints runtime status of all interfaces (or <interface> if given)
$ ./08-ipv6-prefix status [ <interface> ]

# manually deprecate <wan> with tag <who> (w/o <reason> removes dep.)
$ ./08-ipv6-prefix deprecate <wan> <who> [ <reason> ] 
```

More sample configurations can be found in the `examples` directory.

#### Dynamic DNS Configuration

DNS configuration is documented in `etc/nmutils/ddns-functions`.
The `etc/NetworkManager/dispatcher.d/09-ddns` dispatcher script
enables the DDNS features, eg

`NMCONF/ddns-<WAN>.conf`
```
DDNS_ZONE=example.net.
DDNS_RREC_A_NAME=wan.example.net.
```

which would set the `A` record for wan.example.net to the public
IPv4 addresses on `<WAN>` when it's up, and remove the record when the
interface is down.

Again, there are many more configuration options in the documentation,
including fallback addresses, setting TXT, CNAME, AAAA values,
assignment of IPv6 prefix addresses assigned by `08-ipv6-prefix`, and
configuration for locks and `nsupdate` keys.  Configuration for
DDNS addresses assigned by `08-ipv6-prefix` are placed in

`NMCONF/ddns-<WAN>-from-<WAN>.conf` - for WAN addresses

`NMCONF/ddns-<LAN>-from-<WAN>.conf` - for LAN delegated addresses from WAN

Optionally, the systemd service files `ddns-onboot@.service` and 
`ddns-onboot@.timer` can be installed, and enabled with
```
$ systemctl daemon-reload
$ systemctl enable ddns-onboot@<INTERFACE>.timer
```
to perform late boot DDNS setup that may not have been possible during
system boot.

### Examples

There are extensive configuration examples in the source under
`examples/simple` and `examples/complex`.  In addition, refer
to the [Documentation](#documentation) to see complete descriptions of all
the configuration options (there are **lots**).

### Troubleshooting

By default, the scripts log minimal informational messages to syslog
under the daemon facility (info and error).  To track down problems,
verbose debug messages may be enabled by adding the file
`NMCONF/general.conf` containing
```
nmg_show_debug=1
```

Debug messages are logged as daemon.debug, so your syslog daemon
should be configured to direct those messages someplace useful.
Logging may be sent to stderr by setting `nmg_log_stderr=1` to
ease tracing any problems.

In addition, the `test` directory in the source includes "mock"
programs that can be used to simulate many programs such as
`nmcli`, `ip`, `dig` and `dhclient` and others (see the documentation
in those scripts for details).  NOTE: configuration in
the `test` directory is located in `test/conf`

Support Functions
-----------------

The included support scripts `general-functions` and `ddns-functions`
offer an extensive and well tested set of BASH functions which can be
useful in creating additional dispatch scripts.  They include:

- Logging functions
- Configuration (optionally required) file parsing
- File creation/removal with error reporting
- Command/daemon execution with output capture
- Hex-decimal number conversion
- IPv4/IPv6 address query and assignment with error handling
- IPv6 network and host prefix creation and address creation
- Full configuration of all paths, prefixes and configuration
  locations
- Extensive debugging hooks to ease development with scripts,
  including stderr logging redirect and dry-run command execution.
- nsupdate-based Dynamic DNS (optionally asynchronous) and serialized
  with locking

### Usage

To use the support functions in your own dispatch scripts, just
include them; for example add the following to the start of
your script (set default $NMUTILS based on install location)

```
NMUTILS="${NMUTILS:-/etc/nmutils}"
NMG="${NMG:-$NMUTILS/general-functions}"
[ -f "$NMG" -a -r "$NMG" ] && . "$NMG" || {
  echo >&2 "Unable to load $NMG" && exit 2; }
```

Functions can be fully customized, either by setting file-local
defaults before including them, or creating a global configuration
file to set new defaults for all scripts (default:
`NMCONF/general.conf`).  All customization variables and
their defaults are documented in the scripts.

Documentation
-------------

Each script fully documents all the functions it provides at the
beginning of the script.  To see the list of supported functions and
configuration settings, please refer to the following files:

- General utility functions:
`etc/nmutils/general-functions`

- Dynamic DNS utility functions: 
`etc/nmutils/ddns-functions`

The following utility scripts only document configuration, as they
are are just executed by NetworkManager:

- IPv6 Prefix Delegation trigger script: 
`etc/NetworkManager/dispatcher.d/08-ipv6-prefix`

- Dynamic DNS trigger script:
`etc/NetworkManager/dispatcher.d/09-ddns`

- radvd.conf generation script:
`etc/NetworkManager/dispatcher.d/95-radvd-gen`

- general action to service trigger script:
`etc/NetworkManager/dispatcher.d/96-interface-action`

- Transmission config generation script:
`etc/NetworkManager/dispatcher.d/90-transmission`

SELinux
-------

A source module for SELinux is provided in the selinux directory.
The module provides rules allowing `08-ipv6-prefix` to manage the
dhcp client, manage radvd and perform DDNS functions. 
`sudo make -C selinux install` will build and install the module
(`selinux-policy-devel` is required)

Test Suite
----------

A complete test suite with over 1400 tests for all documented
functions, and most of the utility scripts can be found in the
`test` directory.  To run all tests (with detailed reporting), 
simply run `make check`.

Support
-------

nmutils is hosted at
[github.com/sshambar/nmutils](https://github.com/sshambar/nmutils).
Please feel free to comment or send pull requests if you find
bugs or want to contribute new features.

I can be reached via email at:
"Scott Shambarger" `<devel [at] shambarger [dot] net>`

License
-------

nmutils is licensed under the GPLv3 and LGPLv3 (for library scripts)
