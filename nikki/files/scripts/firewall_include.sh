#!/bin/sh

. "$IPKG_INSTROOT/lib/functions.sh"
. "$IPKG_INSTROOT/etc/nikki/scripts/include.sh"

config_load nikki
config_get_bool enabled "config" "enabled" 0
config_get_bool core_only "config" "core_only" 0
config_get tun_listener_name "core" "tun_listener_name"
config_get_bool proxy_enabled "proxy" "enabled" 0 
config_get tcp_mode "proxy" "tcp_mode"
config_get udp_mode "proxy" "udp_mode"

# This script is registered as an fw4 include and is therefore executed on every
# firewall reload, and it is also invoked directly when nikki starts. Drop the
# rules of a previous run first, otherwise repeated runs stack duplicates.
flush_nikki_rules() {
	local chain handle handles
	for chain in input forward output; do
		handles=$(nft --json list table inet fw4 2>/dev/null | jsonfilter -q -e "@['nftables'][*]['rule']" | jsonfilter -q -a -e "@[@['chain']='$chain']" | jsonfilter -q -a -e "@[@['comment']='nikki']" | jsonfilter -q -a -e "@[*]['handle']")
		for handle in $handles; do
			nft delete rule inet fw4 "$chain" handle "$handle"
		done
	done
}

if [ "$enabled" = 1 ] && [ "$core_only" = 0 ] && [ "$proxy_enabled" = 1 ]; then
	flush_nikki_rules
	if [ "$tcp_mode" = "tun" ] || [ "$udp_mode" = "tun" ]; then
		tun_device=$(yq -M "(.tun | select(.enable) | .device) // (.listeners[] | select(.name == \"$tun_listener_name\" and .type == \"tun\") | .device)" "$RUN_PROFILE_PATH")
		nft insert rule inet fw4 input iifname "$tun_device" counter accept comment "nikki"
		nft insert rule inet fw4 forward oifname "$tun_device" counter accept comment "nikki"
		nft insert rule inet fw4 forward iifname "$tun_device" counter accept comment "nikki"
	fi
	if [ "$tcp_mode" = "ebpf" ] || [ "$udp_mode" = "ebpf" ]; then
		# eBPF shared (LAN proxy) data-plane rewrites both the destination
		# (request) and source (reply) address into 127.128.0.0/9. fw4's
		# default "ct state invalid drop" would otherwise drop the rewritten
		# reply traffic because it no longer matches the original conntrack
		# entry, so it needs an explicit accept before that drop rule, on
		# both input (replies arriving back on br-lan) and output (locally
		# generated/forwarded packets leaving with the rewritten source).
		nft insert rule inet fw4 input ip daddr 127.128.0.0/9 counter accept comment "nikki"
		nft insert rule inet fw4 output ip saddr 127.128.0.0/9 counter accept comment "nikki"
	fi
fi

exit 0
