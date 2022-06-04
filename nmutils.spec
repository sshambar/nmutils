#
# Copyright (C) 2022 Scott Shambarger, Kenneth Porter
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

%global with_selinux 1
%global selinuxtype       targeted
%global selinuxmodulename nmutils

Name:           nmutils
Version:        20220603
Release:        1%{?dist}
Summary:        Network Manager Utility Scripts
BuildArch:      noarch

License:        GPLv3+
URL:            https://github.com/sshambar/nmutils
Source0:        https://github.com/sshambar/nmutils/archive/%{version}/%{name}-%{version}.tar.gz
Requires:       NetworkManager
Requires:       (selinux-policy >= %{_selinux_policy_version} if selinux-policy-%{selinuxtype})
Requires:       (%{name}-selinux if selinux-policy-%{selinuxtype})
Suggests:       %{name}-selinux
BuildRequires:  make
%{?systemd_ordering}

%description
A collection of BASH based utility scripts and support functions for
use with Gnome's NetworkManager dispatcher.

%if 0%{?with_selinux}
%package selinux
Summary:        Selinux policy module
BuildArch:      noarch
License:        GPLv3+
Requires:       selinux-policy-%{selinuxtype}
Requires(post): selinux-policy-%{selinuxtype}
BuildRequires:  selinux-policy-devel
%{?selinux_requires}

%description selinux
Install nmutils-selinux to ensure your system contains the SELinux policy
required for 08-ipv6-prefix to spawn dhclient, and as a child of dhclient
manage radvd and perform DDNS operations.
%endif

%prep
%autosetup
# /etc/nmutils -> /usr/share/nmutils
# /usr/share/nmutils/conf -> <sysconf>/nmutils/conf
# /etc/NM/dispatcher.d -> /usr/lib/NM/dispatcher.d
# /etc/NetworkManager - > <sysconf>/NetworkManager
find . -type f -exec bash -c 't=$(stat -c %y "$0"); %{__sed} -i -e "s|/etc/nmutils|%{_datadir}/nmutils|g" -e "s|%{_datadir}/nmutils/conf|%{_sysconfdir}/nmutils/conf|g" -e "s|/etc/NetworkManager/dispatcher.d|%{_prefix}/lib/NetworkManager/dispatcher.d|g" -e "s|/etc/NetworkManager|%{_sysconfdir}/NetworkManager|g" "$0"; touch -d "$t" "$0"' {} \;
# interface-dispatcher doc is copy to <sysconf>/NetworkManager/dispatcher.d
find . -type f -name interface-dispatcher -exec bash -c 't=$(stat -c %y "$0"); %{__sed} -i -e "s|%{_prefix}/lib/NetworkManager/dispatcher.d|%{_sysconfdir}/NetworkManager/dispatcher.d|g" "$0"; touch -d "$t" "$0"' {} \;

%if 0%{?with_selinux}
%build selinux
pushd selinux
%{__make} -f %{_datadir}/selinux/devel/Makefile %{selinuxmodulename}.pp
%{__rm} -f %{selinuxmodulename}.pp.bz2
bzip2 -9 %{selinuxmodulename}.pp
popd
%endif

%check
%{__make} SRC_ROOT=%{buildroot} -C test

%install
%{__install} -dp %{buildroot}%{_sysconfdir}/nmutils/conf
%{__install} -dp %{buildroot}%{_datadir}/nmutils
%{__install} -dp %{buildroot}%{_prefix}/lib/NetworkManager/dispatcher.d
%{__install} -dp %{buildroot}%{_unitdir}

%{__install} -p etc/NetworkManager/dispatcher.d/* %{buildroot}%{_prefix}/lib/NetworkManager/dispatcher.d
%{__install} -p -m 0644 etc/nmutils/* %{buildroot}%{_datadir}/nmutils
%{__chmod} +x %{buildroot}%{_datadir}/nmutils/interface-dispatcher
%{__install} -p -m 0644 etc/systemd/system/* %{buildroot}%{_unitdir}

%if 0%{?with_selinux}
# install policy modules
%{__install} -dp %{buildroot}%{_datadir}/selinux/packages/%{selinuxtype}
%{__install} -p -m 0644 selinux/%{selinuxmodulename}.pp.bz2 %{buildroot}%{_datadir}/selinux/packages/%{selinuxtype}
%endif

%preun
if [[ $1 -eq 0 ]] && command -v systemctl >/dev/null; then
  # Package removal, not upgrade
  # disable service/timers (systemd macros don't handled templated units well)
  if systemctl is-enabled ddns-onboot@.service ddns-onboot@.timer >/dev/null; then
    systemctl --no-reload disable ddns-onboot@
  fi
fi

%if 0%{?with_selinux}
%post selinux
%selinux_modules_install -s %{selinuxtype} %{_datadir}/selinux/packages/%{selinuxtype}/%{selinuxmodulename}.pp.bz2 &> /dev/null

%postun selinux
if [ $1 -eq 0 ]; then
  # Package removal, not upgrade
  %selinux_modules_uninstall -s %{selinuxtype} %{selinuxmodulename}
fi
%endif

%files
%license LICENSE.md
%doc README.md examples
%{_prefix}/lib/NetworkManager/dispatcher.d/*
%{_datadir}/nmutils
%config %{_sysconfdir}/nmutils
%{_unitdir}/*

%if 0%{?with_selinux}
%files selinux
%license LICENSE.md
%attr(0644,root,root) %{_datadir}/selinux/packages/%{selinuxtype}/%{selinuxmodulename}.pp.bz2 
%ghost %verify(not md5 size mode mtime) %{_sharedstatedir}/selinux/%{selinuxtype}/active/modules/200/%{selinuxmodulename}
%endif

%changelog
* Fri Jun 3 2022 Scott Shambarger <devel at shambarger.net> 20220603-1
- Moved script libraries to datadir, handle instanced systemd files
- Added SELinux subpackage

* Mon May 16 2022 Kenneth Porter <shiva.nmutilsspec at sewingwitch.com> 20220516-1
- Initial spec file
