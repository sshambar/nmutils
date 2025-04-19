# SPDX-License-Identifier: LGPL-3.0-or-later

#meson setup --prefix=/usr -Dpkg=true build
#meson install --destdir=destdir -C build

project('nmutils', version: '20250418', license: 'GPL-3.0-or-later',
	default_options: [ 'sysconfdir=/etc' ],
	meson_version: '>=0.62.0') # test() verbose

# get options
nm_prefix = get_option('prefix')
nm_name = meson.project_name()
nm_sysconfdir = nm_prefix / get_option('sysconfdir')
nm_unitdir = get_option('unitdir')
nm_rundir = get_option('runstatedir')
nm_selinuxtype = get_option('selinuxtype')
nm_datadir = nm_prefix / get_option('datadir')
nm_nmlibdir = get_option('nmlibdir')
nm_ispkg = get_option('pkg')

# get auto SELinux from config
seconfig = '/etc/selinux/config'
semake = '/usr/share/selinux/devel/Makefile'

sed_cmd = find_program('sed')
fs = import('fs')

if nm_nmlibdir == ''
  if fs.is_dir(nm_prefix / 'lib/NetworkManager/dispatcher.d')
    nm_nmlibdir = nm_prefix / 'lib'
  else
    nm_nmlibdir = '/usr/lib'
  endif
endif

if nm_ispkg
  nm_pkgconfdir = nm_sysconfdir / nm_name
else
  nm_pkgconfdir = nm_sysconfdir / nm_name / 'conf'
endif

# systemd units may be disabled with -Dunitdir=no
install_units = (nm_unitdir != '')
if install_units and nm_unitdir == 'auto'
  if nm_ispkg
    systemd_dep = dependency('systemd', method: 'pkg-config', required: false)
    if systemd_dep.found()
      nm_unitdir = systemd_dep.get_variable(pkgconfig: 'systemdsystemunitdir')
    elif fs.is_dir('/usr/lib/systemd/system')
      nm_unitdir = '/usr/lib/systemd/system'
    endif
  elif fs.is_dir('/etc/systemd/system')
    nm_unitdir = '/etc/systemd/system'
  endif
  install_units = (nm_unitdir != 'auto')
endif

install_selinux = (nm_selinuxtype != '')
if install_selinux and nm_selinuxtype == 'auto'
  nm_selinuxtype = ''
  if fs.is_file(seconfig) and fs.is_file(semake)
    seconfig_type = run_command(sed_cmd, '-E', '-n',
				'/^SELINUXTYPE=(.*)$/{s//\\1/p;q;}', seconfig,
				check: true)
    nm_selinuxtype = seconfig_type.stdout().strip()
  endif
  install_selinux = (nm_selinuxtype != '')
endif

if install_selinux
  if nm_ispkg
    sepkgdir = nm_datadir / 'selinux/packages' / nm_selinuxtype
  else
    sepkgdir = '/etc/selinux' / nm_selinuxtype / 'packages'
  endif
  assert(fs.is_file(semake),
	 'selinuxtype set, but selinux-policy-devel package not installed')
endif

# packages have different locations for scripts
if nm_ispkg
  nm_pkglibdir = nm_nmlibdir / 'NetworkManager/dispatcher.d'
  nm_pkgdatadir = nm_datadir / nm_name
else
  nm_pkglibdir = nm_sysconfdir / 'NetworkManager/dispatcher.d'
  nm_pkgdatadir = nm_sysconfdir / nm_name
endif

install_sets = [
  [
    'etc/nmutils',
    nm_pkgdatadir,
    'rw-r--r--',
    [
      'general-functions',
      'ddns-functions',
      'ipv6_utils.sh',
      'dispatcher_action',
    ]
  ],
  [
    'etc/NetworkManager/dispatcher.d',
    nm_pkglibdir,
    'rwxr-xr-x',
    [
      '08-ipv6-prefix',
      '09-ddns',
      '90-transmission',
      '95-radvd-gen',
      '96-interface-action',
    ]
  ],
]

if install_units
  install_sets += [
    [
      'etc/systemd/system',
      nm_unitdir,
      'rw-r--r--',
      [
	'ddns-onboot@.service',
	'ddns-onboot@.timer',
      ],
    ],
  ]
endif

patch_cmd = [
  sed_cmd, '-e', 's|/etc/nmutils|' + nm_pkgdatadir + '|g',
  '-e', 's|' + nm_pkgdatadir + '/conf|' + nm_pkgconfdir + '|g',
  '-e', 's|/etc/NetworkManager|' + nm_sysconfdir + '/NetworkManager|g',
  '-e', 's|' + nm_sysconfdir + '/NetworkManager/dispatcher.d|' +
	nm_pkglibdir + '|g',
  '-e', 's|' + nm_pkglibdir + '/##-ifd|' + nm_sysconfdir +
	'/NetworkManager/dispatcher.d/##-ifd' + '|g',
  '-e', 's|/run/|' + nm_rundir + '/|g',
  '@INPUT@',
]

sepatch_cmd = [
  sed_cmd,
  '-e', 's|^/usr/lib/|' + nm_nmlibdir + '/|g',
  '-e', 's|^/etc/|' + nm_sysconfdir + '/|g',
  '@INPUT@',
]

selinux_files =  [
  'nmutils.fc',
  'nmutils.te',
]
#
# INSTALL
#
foreach p: install_sets
  foreach tgt: p[3]
    custom_target(command: patch_cmd, capture: true, input: p[0] / tgt,
		  output: tgt, install: true, install_dir: p[1],
		  install_mode: p[2], install_tag: 'base')
  endforeach
endforeach

install_emptydir(nm_pkgconfdir, install_tag: 'base')
predown_symlinks = [
  '08-ipv6-prefix',
  '96-interface-action',
]
foreach p: predown_symlinks
  install_symlink(p, install_dir: nm_pkglibdir / 'pre-down.d',
		  install_tag: 'base', pointing_to: '..' / p)
endforeach

if install_selinux

  sedeps = []
  foreach p: selinux_files
    sedeps += custom_target(command: sepatch_cmd, capture: true,
			    input: 'selinux' / p, output: p)
  endforeach

  custom_target(command: [ find_program('make'), '-f',
			   meson.current_source_dir() / 'selinux/GNUmakefile',
			   'VPATH=.', 'nmutils.pp.bz2' ],
		depends: sedeps, output: 'nmutils.pp.bz2', install: true,
		install_dir: sepkgdir, install_tag: 'selinux')
  meson.add_install_script(find_program('semodule'), '-s', nm_selinuxtype,
			   '-i', sepkgdir / 'nmutils.pp.bz2',
			   install_tag: 'selinux', skip_if_destdir: true)
endif

#
# TESTS
#
testdir = meson.current_source_dir() / 'test'
builddir = meson.current_build_dir()

test_files = [
  'general-test',
  'ddns-test',
  'nm-ddns-test',
  'ipv6-prefix-addr-test',
  'ipv6-prefix-nm-test',
  'ipv6-prefix-dhclient-test',
  'ipv6-prefix-dhcpcd-test',
]

test_env = [
  'TEST_NMUTILS=' + builddir,
  'TEST_NMDIR=' + builddir,
  'TEST_OUT=' + builddir / 'results',
  'TEST_RUNDIR=' + builddir / 'run/nmutils',
]

foreach p: test_files
  test(p, find_program(p, dirs: testdir), args: [ 'strict', 'verbose' ],
       env: test_env, is_parallel: false, verbose: true, workdir: testdir)
endforeach

radvd_tests = [
  'radvd-test-1',
  'radvd-test-2',
  'radvd-test-3',
  'radvd-test-4',
]

make_cmd = find_program('make')
foreach p: radvd_tests
  test(p, make_cmd, args: [ p ], env: test_env, is_parallel: false,
       workdir: testdir)
endforeach
