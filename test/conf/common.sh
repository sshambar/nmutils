# common.sh sourced before any tests start

# shellcheck shell=bash
# don't use syslog
export nmg_log_stderr=1
# never use default logger
export NMG_LOGGER=echo

export SRC_ROOT=${SRC_ROOT-..}
export TEST_ROOT=${TEST_ROOT-.}
export TEST_CONF=${TEST_CONF-$TEST_ROOT/conf}
export TEST_OUT=${TEST_OUT-$TEST_ROOT/results}
export TEST_BIN=${TEST_BIN-$TEST_ROOT/bin}

export NMUTILS="${NMUTILS:-$SRC_ROOT/etc/nmutils}"
export NMCONF="${NMCONF:-$TEST_ROOT/conf}"

# for state/pids
export RUNDIR="${RUNDIR:-$TEST_ROOT/run/nmutils}"
[ -d "$RUNDIR" ] || mkdir -p "$RUNDIR"

