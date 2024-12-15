
.SUFFIXES:
.SUFFIXES: .pp .bz2

V := 0
VB_0 := @
VB := $(VB_$(V))
SELINUX_MAKE := /usr/share/selinux/devel/Makefile

all: nmutils.pp.bz2

nmutils.pp.bz2: selinux-devel nmutils.pp
	$(VB)rm -f "$@"
	bzip2 -k -9 nmutils.pp

.PHONY: selinux-devel
selinux-devel:
	$(VB)[ -f "$(SELINUX_MAKE)" ] || { \
	 echo "Install selinux-policy-devel before compiling policy"; \
	 false; }

local_clean:
	$(VB)rm -f nmutils.pp.bz2 nmutils.if

# clean defined in include, add dep
clean: local_clean

-include $(SELINUX_MAKE)
