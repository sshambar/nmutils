#! /bin/bash
#
# Calculate IPv6 address segments entirely in bash
#
# Source: https://github.com/frankcrawford/bash_ipv6
#
# Based loosely on wg-ip (https://github.com/chmduquesne/wg-ip)
#
# Frank Crawford - <frank@crawford.emu.id.au> - 31-Jul-2021
#
# Functions:
# expand_ipv6 $ip
# - expand out IPv6 ($ip) address with all digits
# compress_ipv6 $ip
# - returns compressed IPv6 address ($ip) under the form recommended by RFC5952
# ipv6_prefix $ip $subnet
# - extract the IPv6 routing prefix from $ip with subnet length $subnet
# - currently requires subnet size a multiple of 4
# ipv6_subnetid $ip $subnet
# - extract the local subnet ID fro unicast address ($ip)
# ipv6_interface $ip
# - IPv6 host or interface part of address ($ip)
# is_ipv6 $ip
# - tests if address ($ip) is a valid IPv6 in either the expanded form
#   or the compressed one
# ipv6_type $ip
# - return IPv6 address ($ip) category

# helper to convert hex to dec (portable version)
hex2dec() {
    [ "$1" != "" ] && printf "%d" "$(( 0x$1 ))"
}

# convert ipv6 to lowercase
# inspired by https://stackoverflow.com/a/51573758/14179001
lowercase_ipv6() { # <ipv6-address> - echoes result
    local lcs="abcdef" ucs="ABCDEF"
    local result="${1-}" uchar uoffset

    while [[ "$result" =~ ([A-F]) ]]; do
        uchar="${BASH_REMATCH[1]}"
        uoffset="${ucs%%${uchar}*}"
        result="${result//${uchar}/${lcs:${#uoffset}:1}}"
    done

  echo -n "$result"
}

# expand an IPv6 address
expand_ipv6() {
    local ip=$(lowercase_ipv6 $1)

    # prepend 0 if we start with :
    [[ "$ip" =~ ^: ]] && ip="0${ip}"

    # expand ::
    if [[ "$ip" =~ :: ]]; then
        local colons=${ip//[^:]/}
        local missing=':::::::::'
        missing=${missing/$colons/}
        local expanded=${missing//:/:0}
        ip=${ip/::/$expanded}
    fi

    local blocks=${ip//[^0-9a-f]/ }
    set $blocks

    printf "%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x\n" \
        $(hex2dec $1) \
        $(hex2dec $2) \
        $(hex2dec $3) \
        $(hex2dec $4) \
        $(hex2dec $5) \
        $(hex2dec $6) \
        $(hex2dec $7) \
        $(hex2dec $8)
}

# returns a compressed IPv6 address under the form recommended by RFC5952
compress_ipv6() {
    local ip=$(expand_ipv6 $1)

    local blocks=${ip//[^0-9a-f]/ }
    set $blocks

    # compress leading zeros
    ip=$(printf "%x:%x:%x:%x:%x:%x:%x:%x\n" \
        $(hex2dec $1) \
        $(hex2dec $2) \
        $(hex2dec $3) \
        $(hex2dec $4) \
        $(hex2dec $5) \
        $(hex2dec $6) \
        $(hex2dec $7) \
        $(hex2dec $8)
    )

    # prepend : for easier matching
    ip=:$ip

    # :: must compress the longest chain
    local pattern
    for pattern in :0:0:0:0:0:0:0:0 \
            :0:0:0:0:0:0:0 \
            :0:0:0:0:0:0 \
            :0:0:0:0:0 \
            :0:0:0:0 \
            :0:0:0 \
            :0:0; do
        if [[ "$ip" =~ $pattern ]]; then
            ip=$(echo $ip | sed "s/$pattern/::/")
            ip=${ip/$pattern/::}
            # if the substitution occured before the end, we have :::
            ip=${ip/:::/::}
            break # only one substitution
        fi
    done

    # remove prepending : if necessary
    [[ "$ip" =~ ^:[^:] ]] && ip=${ip/#:/}

    echo $ip
}

# extract the IPv6 routing prefix - currently requires size a multiple of 4
ipv6_prefix() {
    local prefix=$(expand_ipv6 $1)
    local subnet=${2:-64}
    local subid='0000'

    local xdig=$(( $subnet / 4 ))

    prefix=${prefix:0:$xdig+$xdig/4}

    compress_ipv6 "${prefix}${subid:0:$subnet % 4}::"
}

# extract the local subnet ID
ipv6_subnetid() {
    local ip=$(expand_ipv6 $1)
    local subnet=${2:-64}

    local xdig=$(( $subnet / 4 ))
    local len=$(( 20-$xdig-$xdig/4 ))

    if (( $len <= 0 )); then
	echo "0"
    else
        echo "${ip:$xdig+$xdig/4:$len-1}"
    fi
}

# IPv6 host or interface part of address
ipv6_interface() {
    local ip=$(expand_ipv6 $1)

    compress_ipv6 "::${ip:20}"
}

# a valid IPv6 in either the expanded form or the compressed one
is_ipv6() {
    local orig=$(lowercase_ipv6 $1)
    local expanded="$(expand_ipv6 $orig)"
    [ "$orig" = "$expanded" ] && return 0
    local compressed="$(compress_ipv6 $expanded)"
    [ "$orig" = "$compressed" ] && return 0
    return 1
}

# return IPv6 address category
ipv6_type() {
    local ip=$(lowercase_ipv6 $1)

    # Technically should be /10 but ipv6_prefix doesn't handle that
    if [[ $(ipv6_prefix $ip 16) == 'fe80::' ]]; then
	echo 'Link-local'
    else
	case $(ipv6_prefix $ip 8) in
	::) echo 'Special' ;;
	fc::) echo 'Global ULA' ;;
	fd::) echo 'Local ULA' ;;
	ff::) echo 'Multicast' ;;
	f?::) echo 'Invalid' ;;
	*) echo 'Unicast' ;;
	esac
    fi
}
