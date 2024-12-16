# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2022-24 Scott Shambarger, Kenneth Porter
#
%bcond_without selinux
%bcond_with    test

%global selinuxtype targeted

%if 0%{?srpm}
%undefine dist
%endif

Name:           nmutils
Version:        devel
Release:        1%{?dist}
Summary:        Network Manager Utility Scripts
BuildArch:      noarch

License:        GPL-3.0-or-later AND LGPL-3.0-or-later
URL:            https://github.com/sshambar/nmutils
Source0:        https://github.com/sshambar/nmutils/archive/%{version}/%{name}-%{version}.tar.gz
Requires:       NetworkManager
Requires:       iproute
Requires:       procps-ng
Requires:       systemd >= 236
Recommends:     bind-utils
Recommends:     util-linux-core
Recommends:     ndisc6
Recommends:     dhcp-client
Suggests:       dhcpcd
Suggests:       radvd
BuildRequires:  make
BuildRequires:  meson
%if %{with selinux}
Requires:       (%{name}-selinux if selinux-policy-%{selinuxtype})
%endif
BuildRequires:  systemd-rpm-macros
%{?systemd_ordering}

%description
A collection of BASH based utility scripts and support functions for
use with Gnome's NetworkManager dispatcher.

%if %{with selinux}
%package selinux
Summary:        Selinux policy module
BuildArch:      noarch
License:        GPL-3.0-or-later
BuildRequires:  make
BuildRequires:  bzip2
BuildRequires:  selinux-policy-devel
%{?selinux_requires}
Requires:       selinux-policy-%{selinuxtype}
Requires(post): selinux-policy-%{selinuxtype}

%description selinux
Install nmutils-selinux to ensure your system contains the SELinux policy
required for dhcp clients to run 08-ipv6-prefix, manage radvd and
perform DDNS operations.
%endif

%prep
%autosetup

%build
%meson \
  -Dselinuxtype=%{?with_selinux:%{selinuxtype}} \
  -Dunitdir=%{_unitdir} \
  -Dnmlibdir=/usr/lib \
  -Drunstatedir=%{_runstatedir} \
  -Dpkg=true

%meson_build

%check
%if %{with test}
%meson_test
%endif

%install
%meson_install \
  --tags base

%if %{with selinux}
%meson_install \
  --tags selinux
%endif

%preun
if [[ $1 -eq 0 ]] && command -v systemctl >/dev/null; then
  # Package removal, not upgrade
  # disable service/timers (systemd macros don't handled templated units well)
  if systemctl is-enabled ddns-onboot@.service ddns-onboot@.timer >/dev/null; then
    systemctl --no-reload disable ddns-onboot@
  fi
fi

%files
%license LICENSE
%license LICENSE.LGPLv3
%doc README.md examples
%{_prefix}/lib/NetworkManager/dispatcher.d/*
%{_datadir}/nmutils
%config %{_sysconfdir}/nmutils
%{_unitdir}/*

%if %{with selinux}

%pre selinux
%selinux_relabel_pre -s %{selinuxtype}

%post selinux
%selinux_modules_install -s %{selinuxtype} %{_datadir}/selinux/packages/%{selinuxtype}/nmutils.pp.bz2 || :

%postun selinux
if [ $1 -eq 0 ]; then
  # Package removal, not upgrade
  %selinux_modules_uninstall -s %{selinuxtype} nmutils || :
fi

%posttrans selinux
%selinux_relabel_post -s %{selinuxtype} || :

%files selinux
%license LICENSE
%attr(0644,root,root) %{_datadir}/selinux/packages/%{selinuxtype}/nmutils.pp.bz2
%ghost %verify(not md5 size mode mtime) %{_sharedstatedir}/selinux/%{selinuxtype}/active/modules/200/nmutils
%endif

%changelog
* Mon Dec 16 2024 Scott Shambarger <devel at shambarger.net> 20241216-1
- Release 20241216

* Thu Nov 28 2024 Scott Shambarger <devel at shambarger.net> 20241126-1
- Updated for meson build
- Config for package now in /etc/nmutils

* Tue Jun 21 2022 Scott Shambarger <devel at shambarger.net> 20220621-1
- Moved script libraries to datadir, handle instanced systemd files
- Added SELinux subpackage

* Mon May 16 2022 Kenneth Porter <shiva.nmutilsspec at sewingwitch.com> 20220516-1
- Initial spec file
