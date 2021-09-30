#! /bin/bash
#
# Calculate IPv6 address segments entirely in bash
#
# Based loosely on wg-ip (https://github.com/chmduquesne/wg-ip)
#
# IPv6 definitions from https://en.wikipedia.org/wiki/IPv6_address
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
# ipv6_subnetid $ip $subnet $fmt
# - extract the local subnet ID from unicast address ($ip) with optional $fmt
# ipv6_interface $ip
# - IPv6 host or interface part of address ($ip)
# ipv6_split_mask $ip/$mask
# - returns 2 values $ip and $mask
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
    local ip=$(lowercase_ipv6 ${1:-::1})

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
            ip=${ip/$pattern/::}
            # if the substitution occured before the end, we have :::
            ip=${ip/:::/::}
            break # only one substitution
        fi
    done

    # remove prepending : if necessary
    [[ "$ip" =~ ^:[^:] ]] && ip=${ip/#:/}

    echo -n $ip
}

# extract the IPv6 routing prefix
ipv6_prefix() {
    local prefix=$(expand_ipv6 $1)
    local subnet=${2:-64}

    local nibble=''

    (( $subnet > 64 )) && subnet=64

    if (( $subnet % 16 )); then
	nibble=$(printf "%04x" "$(( 0x${prefix:($subnet/16)*5:4} & ~((1<<(16-$subnet%16))-1) ))")
    fi

    compress_ipv6 "${prefix:0:($subnet/16)*5}${nibble}::"
}

# extract the local subnet ID
ipv6_subnetid() {
    local ip=$(expand_ipv6 $1)
    local subnet=${2:-64}
    local fmt="${3:-%x}"

    local len=$(( 64-$subnet ))

    if (( $len < 0 || $len > 16 )); then
	# Not really valid for non-route entries
	echo -n '-'
    else
        ip=${ip//:/}
        printf "$fmt" "$(( 0x${ip:14:2} & ((1<<$len)-1) ))"
    fi
}

# IPv6 host or interface part of address
ipv6_interface() {
    local ip=$(expand_ipv6 $1)

    compress_ipv6 "::${ip:20}"
}

# split into two parts, the address and the mask
ipv6_split_mask() {
    local ip=${1:-::/0}

    set ${ip/\// }

    echo -n $1 ${2:-128}
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

    if [[ $(ipv6_prefix $ip 10) == 'fe80::' ]]; then
	echo -n 'Link-local'
    elif [[ $(ipv6_prefix $ip 10) == 'fec0::' ]]; then
	echo -n 'Site-local (deprecated)'
    elif [[ $(ipv6_prefix $ip 16) == '2002::' ]]; then
	echo -n '6to4'
    elif [[ $(ipv6_prefix $ip 16) == '3ffe::' ]]; then
	echo -n '6bone (returned)'
    elif [[ $(ipv6_prefix $ip 32) == '2001::' ]]; then
	echo -n 'Teredo tunneling'
    else
	case $(ipv6_prefix $ip 8) in
	::) echo 'Special' ;;
	fc00::) echo -n 'Global ULA' ;;
	fd00::) echo -n 'Local ULA' ;;
	ff00::) echo -n 'Multicast' ;;
	f?00::) echo -n 'Invalid' ;;
	*) echo -n 'Unicast' ;;
	esac
    fi
}
