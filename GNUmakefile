#
# GNU Makefile to:
#   - create 'dist' source tarball
#   - install/uninstall nmutils (requires meson/ninja)
#   - create patched 'tarball' for direct install
#   - create SRPM (requires rpmbuild)
#   - build RPM (requires mock)
#
# 'make help' for options
#

prefix := /usr

SED := sed
TAR := tar
MESON := meson
NINJA := ninja
RPMBUILD := rpmbuild
MOCK := mock

TMPDIR := ./tmp

V := 0
VB_0 := @
VB := $(VB_$(V))

# official version in meson.build
VERSION := $(shell $(SED) -E -n "/^.*[[:space:],]*version[[:space:]]*:[[:space:]]*'([^']+)'.*$$/{s//\\1/p;q;}" meson.build || :)
ifeq ($(VERSION),)
  $(error Unable to extract version from meson.build)
endif

PACKAGE := nmutils
DISTDIR := $(PACKAGE)
DISTNAME := $(PACKAGE)-$(VERSION)
TARBALL := $(DISTNAME).tgz
DIST := $(DISTNAME).tar.gz

.SUFFIXES:

.PHONY: Makefile all
all: build

.PHONY: help
help:
	@echo "Usage: make <target> [ <variable>=<value>... ]"
	@echo "<target> may be:"
	@echo "   help - show this help"
	@echo "   all (default) - configure (uses MESON_FLAGS)"
	@echo "   install - install files (DESTDIR=<dir> honored)"
	@echo "   uninstall - uninstall files (DESTDIR honored)"
	@echo "   tarball - create patched $(TARBALL) (uses MESON_FLAGS) "
	@echo "   dist - create $(DIST) with source files"
	@echo "   srpm - create SRPM for building"
	@echo "   rpm - build rpm using mock"
	@echo "   check - run all tests"
	@echo
	@echo "<variable> may be (with defaults):"
	@echo "  prefix=$(prefix)"
	@echo "  MESON_FLAGS=<any of the following>"
	@echo "    -Dpkg=false         - =true for packaged install"
	@echo "    -Dnmlibdir=/usr/lib - NetworkManager system libdir"
	@echo "    -Drunstatedir=/run  - runtime state dir"
	@echo "    -Dselinuxtype=auto  - SELinux type (auto-detected)"
	@echo "    -Dunitdir=auto      - systemd unit dir (auto-detected)"

# order-only test for commands
.SUFFIXES: .cmd
%.cmd:
	$(VB)for cmd in $*; do \
	 type >/dev/null 2>/dev/null "$$cmd" || \
	 { echo "$$cmd not found (please install first)"; exit 1; } \
	done

build/build.ninja: | $(MESON).cmd $(NINJA).cmd
	@echo $(MESON) setup --prefix="$(prefix)" $(MESON_FLAGS) build
	$(VB)$(MESON) setup --prefix="$(prefix)" $(MESON_FLAGS) build || { \
	 rm -rf build; false; }

.PHONY: build
build: build/build.ninja
	$(MESON) compile -C build

.PHONY: install
install: build
	DESTDIR="$(DESTDIR)" $(MESON) install -C build

.PHONY: uninstall
uninstall: build
	cd build && DESTDIR="$(DESTDIR)" $(NINJA) uninstall
	$(VB)if command >/dev/null -v semodule; then \
	  echo semodule -r nmutils && semodule -r nmutils; \
	 else :; fi

.PHONY: dist
dist: clean
	$(VB)if [ -n "$$($(TAR) --version | grep GNU)" ]; then \
	 $(TAR) czf "$(DIST)" --exclude "$(DIST)" --transform "s/^[.]/$(DISTDIR)/S" ./* ./.gitignore; \
	else \
	 $(TAR) czf "$(DIST)" --exclude "$(DIST)" -s "/^[.]/$(DISTDIR)/S" ./* ./.gitignore; \
	fi
	@echo "Source tar created: $(DIST)"

.PHONY: srpm
srpm: DISTDIR=$(DISTNAME)
srpm: dist | $(RPMBUILD).cmd
	$(VB)mkdir "$(TMPDIR)" && mv "$(DIST)" "$(TMPDIR)"
	$(VB)$(SED) -E -e 's/(Version:[[:space:]]+).*$$/\1$(VERSION)/'\
	 -e 's/(Name:[[:space:]]+).*$$/\1$(PACKAGE)/' \
	 nmutils.spec > "$(TMPDIR)/$(PACKAGE).spec"
	$(RPMBUILD) -D "_topdir $(TMPDIR)" -D "_sourcedir $(TMPDIR)"\
	 -D "_rpmdir $(TMPDIR)" -D "_specdir $(TMPDIR)"\
	 -D "_builddir $(TMPDIR)" -D "_srcrpmdir ." -D "srpm 1" \
	 -bs "$(TMPDIR)/$(PACKAGE).spec"
	$(VB)rm -rf "$(TMPDIR)"

.PHONY: rpm
rpm: srpm | $(MOCK).cmd
	$(MOCK) $(MOCK_FLAGS) $(PACKAGE)-$(VERSION)-*.src.rpm

.PHONY: tarball
tarball: DESTDIR=root
tarball: clean install
	$(VB)$(TAR) czf $(TARBALL) -C build/root .
	@echo "Install tar created: $(TARBALL)"
	$(VB)rm -rf build/root

.PHONY: check
check:
	$(MAKE) -C test

.PHONY: clean
clean:
	-make -C selinux clean V=$(V)
	make -C test clean V=$(V)
	$(VB)rm -f *.tar.gz *.tgz *.src.rpm
	$(VB)rm -rf build "$(TMPDIR)"
