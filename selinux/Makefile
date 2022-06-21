
all: nmutils.pp

nmutils.pp: nmutils.te nmutils.fc
	@[ -f /usr/share/selinux/devel/Makefile ] || \
	{ echo "Install selinux-policy-devel before compiling policy"; exit 1; }
	make -f /usr/share/selinux/devel/Makefile $@

clean:
	@rm -f nmutils.pp
	@rm -f nmutils.if
	@rm -rf tmp/
