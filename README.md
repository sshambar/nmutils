
Network Manager Utility Scripts
================================

A collection of BASH based utility scripts and support functions for
use with Gnome's NetworkManager dispatcher.

- [Included Dispatch Scripts](#included-dispatch-scripts)
- [Setup](#setup)
 - [Prerequisites](#prerequisites)
 - [Installation](#installation)
 - [Configuration](#configuration)
 - [Examples](#examples)
 - [Troubleshooting](#troubleshooting)
- [Support Functions](#support-functions)
 - [Usage](#usage)
- [Documentation](#documentation)
- [Support](#support)
- [License](#license)

Included Dispatch Scripts
-------------------------

- **Dynamic DNS** The dispatch script will use `nsupdate` to set
 or clear DNS entries based on interface state.  Supports address
 assignment to A or AAAA records (with fallback values), and
 assignment of other records (such as CNAME or TXT) individually
 configurable for each interface.
- **IPv6 Prefix Delegation** The dispatch script will spawn a new
 `dhclient` instance to request an IPv6 prefix (as well as WAN address),
 and then assign sub-prefixes from the delegated prefix to the LAN interfaces.
 Simple configuration allows fully automatic behavior,
 but can be configured to fully control sub-prefix and address
 creation by interface.  Also supports Dynamic DNS based on prefix
 assignment similar to the interface state DNS script above.
- **radvd.conf Generation** The dispatch script will create
 `/etc/radvd.conf` based on the prefixes assigned to interfaces defined
 in the template `/etc/NetworkManager/radvd.conf.templ`

Setup
-----

### Prerequisites

- [NetworkManager](https://wiki.gnome.org/Projects/NetworkManager)
- [Bash](http://www.gnu.org/software/bash/)
- Basic Command Line Tools: `pgrep rm ip`
- Optional Tools: `logger radvd dig nsupdate flock dhclient nmcli`

### Installation

To use the included scripts, just install them someplace they can be
executed by NetworkManager's dispatcher scripts (generally
`/etc/NetworkManager/dispatcher.d`) and copy the support files to
locations they can be included (default: `/etc/nmutils`).

- `/etc/NetworkManager/dispatcher.d/08-ipv6-prefix`
- `/etc/NetworkManager/dispatcher.d/09-ddns`
- `/etc/nmutils/general-functions`
- `/etc/nmutils/ddns-functions`

### Configuration

#### IPv6 Prefix Delegation Configuration

The prefix delegation feature supports multiple address/prefix delegations,
from multiple upstream DHCP servers, to multiple LAN interfaces,
with full address aging, DAD checks, and radvd/DNS hooks.

All configuration for prefix delegation is documented in the file
`08-ipv6-prefix`.  Basic prefix delegation is enabled as simply as creating a
configuration file for the WAN interface the prefix will be queried
on:

- `/etc/nmutils/conf/ipv6-prefix-<WAN>.conf`
~~~~
WAN_LAN_INTFS="<LAN1> <LAN2>..."
~~~~

Where `<WAN>` and `<LAN#>` should be replaced by the interface names (eth0
etc).

NetworkManager should have WAN interface configured with
"ipv6.method=link-local" (or "manual"), and the `08-ipv6-prefix`
script should be installed in the `dispatcher.d` directory,
and {general,ddns}-functions installed in `/etc/nmutils`.

There are many more configuration options in the documentation, 
and per-LAN configuration can be set in the optional files, example:

- `/etc/nmutils/conf/ipv6-prefix-<LAN>-from-<WAN>.conf`
~~~~
# trigger the radvd.conf generation script
NMG_RADVD_TRIGGER="/etc/NetworkManager/dispatcher.d/95-radvd-gen"
~~~~

#### Dynamic DNS Configuration

DNS configuration is documented in `ddns-functions`.  Install that
file in `/etc/nmutils`, and optionally the `09-ddns` file in the 
`dispatcher.d` directory. A very simple example configuration is:

- `/etc/nbmutils/conf/ddns-<WAN>.conf`

~~~~
DDNS_ZONE=example.net.
DDNS_RREC_A_NAME=wan.example.net.
~~~~

which would set the `A` record for wan.example.net to the public
IPv4 addresses on `<WAN>` when it's up, and remove the record when the
interface is down.

Again, there are many more configuration options in the documentation,
including fallback addresses, setting TXT, CNAME, AAAA values,
assignment of IPv6 prefix addresses assigned by `08-ipv6-prefix`, and
configuration for locks and `nsupdate` keys.  Configuration for
DDNS addresses assigned by `08-ipv6-prefix` are in:

- `/etc/nmutils/conf/ddns-<WAN>-from-<WAN>.conf`
- `/etc/nmutils/conf/ddns-<LAN>-from-<WAN>.conf`

Optionally, the file:

- `/etc/systemd/system/ddns-onboot@.service`

can be installed, and enabled with:

~~~~
# systemctl daemon-reload
# systemctl enable ddns-onboot@<interface>.service
~~~~

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
verbose debug messages may be enabled by adding the following file:

- `/etc/nmutils/conf/general.conf`

containing the line:

~~~~
nmg_show_debug=1
~~~~

Debug messages are logged as daemon.debug, so your syslog daemon
should be configured to direct those messages someplace useful.

In addition, the `test` directory in the source includes substitute
programs that can be used to simulate `dhclient`, `nsupdate` and `ip`
and logging may be directed to stderr to ease tracing any problems you
may be encountering.  NOTE: configuration in the `test` directory is
located in `test/conf`

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
your script:

~~~~
NMUTILS="${NMUTILS:-/etc/nmutils}"
NMG="${NMG:-$NMUTILS/general-functions}"
[ -f "$NMG" -a -r "$NMG" ] && . "$NMG" || {
  echo 1>&2 "Unable to load $NMG" && exit 2
}
~~~~

Functions can be fully customized, either by setting file-local
defaults before including them, or creating a global configuration
file to set new defaults for all scripts (default:
`/etc/nmutils/conf/general.conf`).  All customization variables and
their defaults are documented in the scripts.

Documentation
-------------

Each script fully documents all the functions it provides at the
beginning of the script.  To see the list of supported functions and
configuration settings, please refer to the following files:

- General utility functions
`/etc/nmutils/general-functions`

- Dynamic DNS utility functions
`/etc/nmutils/ddns-functions`

The following utility scripts only document configuration, as they
are are just executed by NetworkManager:

- IPv6 Prefix Delegation trigger script
`/etc/NetworkManager/dispatcher.d/08-ipv6-prefix`

- Dynamic DNS trigger script
`/etc/NetworkManager/dispatcher.d/09-ddns`

- radvd.conf generation script
`/etc/NetworkManager/dispatcher.d/95-radvd-gen`

- Transmission config generation script
`/etc/NetworkManager/dispatcher.d/90-transmission`

Test Suite
----------

A complete test suite for all documented functions, and most of the utility
scripts can be found in the "test" directory.  To run all tests (with
detailed reporting), simply run "make" in that directory.

Support
-------

nmutils is hosted at [github.com](https://github.com/sshambar/nmutils).
Please feel free to comment or send pull requests if you find bugs
or want to contribute new features.

I can be reached via email at:
"Scott Shambarger" `<devel [at] shambarger [dot] net>`

License
-------

nmutils is licensed under the GPL v3
