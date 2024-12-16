#
# Tests for nmutils
#
# make help for instructions
#
.EXPORT_ALL_VARIABLES:
.SUFFIXES:

V := 0
VB_0 := @
VB := $(VB_$(V))

# command progress to stderr
#VERBOSE := 1
# logs of debug output to stderr
#DEBUG := 2
# test args
TEST_ARGS := strict verbose

TEST_ROOT := .
TEST_BIN := $(TEST_ROOT)/bin
TEST_SHELL := bash

# variables used in configuration files (exported)

# directory with source files
SRC_ROOT := ..
# test configuration files
TEST_CONF := $(TEST_ROOT)/conf
# common test configuration
TEST_COMMON := $(TEST_CONF)/common.conf
# directory for generated results
TEST_OUT := $(TEST_ROOT)/results
# directory for expected results
TEST_EXPECT := $(TEST_ROOT)/expected

# default addrs for ip-mock
IP_MOCK_ADDRS := $(TEST_CONF)/ip-mock-addrs

.PHONY: Makefile all
all: general ddns prefix all-radvd

.PHONY: help
help:
	@echo "make targets:"
	@echo "  all               - run all tests"
	@echo "  general           - run general-funcions tests"
	@echo "  ddns              - run ddns-funcions tests"
	@echo "  prefix            - run ipv6 prefix tests"
	@echo "  all-radvd          - run all radvd tests"
	@echo "  radvd-test-#      - run radvd test # (1, 2, etc)"
	@echo "  bless-radvd-test  - replace a test results (prompts for #)"

.PHONY: general
general:
	$(TEST_SHELL) $(TEST_ROOT)/general-test $(TEST_ARGS)

.PHONY: ddns
ddns:
	$(TEST_SHELL) $(TEST_ROOT)/ddns-test $(TEST_ARGS)
	$(TEST_SHELL) $(TEST_ROOT)/nm-ddns-test $(TEST_ARGS)

.PHONY: prefix
prefix:
	$(TEST_SHELL) $(TEST_ROOT)/ipv6-prefix-addr-test $(TEST_ARGS)
	$(TEST_SHELL) $(TEST_ROOT)/ipv6-prefix-nm-test $(TEST_ARGS)
	$(TEST_SHELL) $(TEST_ROOT)/ipv6-prefix-dhclient-test $(TEST_ARGS)
	$(TEST_SHELL) $(TEST_ROOT)/ipv6-prefix-dhcpcd-test $(TEST_ARGS)

.PHONY: all-radvd
all-radvd: radvd-test-1 radvd-test-2 radvd-test-3 radvd-test-4

$(TEST_OUT):
	$(VB)mkdir "$(TEST_OUT)"

#
# 95-radvd-gen tests
#
# For each test #:
#
#   Config is CONF/radvd-gen.conf - which in turn sets:
#        SRC = CONF/#-radvd.conf.templ
#        DST = OUT/#-radvd.conf
#        IP_MOCK_ADDRS = CONF/#-ip-mock-addrs (if present)
#
#   The output is then compared with EXPECT/#-radvd.conf
#
RADVDGEN_CONF := $(TEST_CONF)/radvd-gen.conf

$(TEST_OUT)/%-radvd.conf: $(TEST_EXPECT)/%-radvd.conf
	@echo "Running radvd-gen test $(TEST_NUM)"
	$(VB)[ -f "$(TEST_CONF)/$(TEST_NUM)-radvd.conf" ] && \
	 cp "$(TEST_CONF)/$(TEST_NUM)-radvd.conf" "$@" || :
	$(VB)VERBOSE=$(VERBOSE) $(TEST_SHELL) $(TEST_ROOT)/radvd-test
	$(VB)diff >/dev/null "$<" "$@" || { \
	   echo "FAIL: $< $@ differ:"; diff "$<" "$@"; }

radvd-test-%: $(TEST_EXPECT)/%-radvd.conf $(TEST_OUT)
	-$(VB)rm -f "$(TEST_OUT)/$*-radvd.conf"
	$(VB)$(MAKE) "$(TEST_OUT)/$*-radvd.conf" TEST_NUM="$*"

.PHONY: bless-radvd-test
bless-radvd-test:
	@echo "WARNING: this will overwrite the expected for this test!"
	$(VB)read -p "Test # to replace (empty to quit): " TEST_NUM && \
	 [ -n "$$TEST_NUM" ] && export TEST_NUM && \
	 $(TEST_SHELL) $(TEST_ROOT)/radvd-test && \
	 cp -f "$(TEST_OUT)/$${TEST_NUM}-radvd.conf" $(TEST_EXPECT)

.PHONY: clean
clean:
	$(VB)rm -rf $(TEST_OUT) ./run
