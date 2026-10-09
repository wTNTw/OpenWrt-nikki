#!/bin/sh

# paths
HOME_DIR="/etc/nikki"
PROFILES_DIR="$HOME_DIR/profiles"
SUBSCRIPTIONS_DIR="$HOME_DIR/subscriptions"
MIXIN_FILE_PATH="$HOME_DIR/mixin.yaml"
RUN_DIR="$HOME_DIR/run"
RUN_PROFILE_PATH="$RUN_DIR/config.yaml"
PROVIDERS_DIR="$RUN_DIR/providers"
RULE_PROVIDERS_DIR="$PROVIDERS_DIR/rule"
PROXY_PROVIDERS_DIR="$PROVIDERS_DIR/proxy"

# log
LOG_DIR="/var/log/nikki"
APP_LOG_PATH="$LOG_DIR/app.log"
CORE_LOG_PATH="$LOG_DIR/core.log"

# temp
TEMP_DIR="/var/run/nikki"
PID_FILE_PATH="$TEMP_DIR/nikki.pid"
STARTED_FLAG_PATH="$TEMP_DIR/started.flag"
BRIDGE_NF_CALL_IPTABLES_FLAG_PATH="$TEMP_DIR/bridge_nf_call_iptables.flag"
BRIDGE_NF_CALL_IP6TABLES_FLAG_PATH="$TEMP_DIR/bridge_nf_call_ip6tables.flag"
ACCEPT_LOCAL_FLAG_PATH="$TEMP_DIR/accept_local.flag"
FLOW_OFFLOADING_FLAG_PATH="$TEMP_DIR/flow_offloading.flag"

# ucode
UCODE_DIR="$HOME_DIR/ucode"
INCLUDE_UC="$UCODE_DIR/include.uc"
MIXIN_UC="$UCODE_DIR/mixin.uc"
HIJACK_UT="$UCODE_DIR/hijack.ut"

# scripts
SH_DIR="$HOME_DIR/scripts"
INCLUDE_SH="$SH_DIR/include.sh"
FIREWALL_INCLUDE_SH="$SH_DIR/firewall_include.sh"
WATCHDOG_SH="$SH_DIR/watchdog.sh"

# persistent (non tmpfs) record of watchdog alarms
WATCHDOG_LOG_PATH="$HOME_DIR/watchdog.log"

# core
CORE_PROC_NAME="mihomo"

# nftables
NFT_DIR="$HOME_DIR/nftables"
GEOIP_CN_NFT="$NFT_DIR/geoip_cn.nft"
GEOIP6_CN_NFT="$NFT_DIR/geoip6_cn.nft"

# functions
format_filesize() {
	local b; b=1
	local kb; kb=$((b * 1024))
	local mb; mb=$((kb * 1024))
	local gb; gb=$((mb * 1024))
	local tb; tb=$((gb * 1024))
	local pb; pb=$((tb * 1024))
	local size; size="$1"
	if [ -n "$size" ]; then
		if [ "$size" -lt "$kb" ]; then
			echo "$(awk "BEGIN {print $size / $b}") B"
		elif [ "$size" -lt "$mb" ]; then
			echo "$(awk "BEGIN {print $size / $kb}") KB"
		elif [ "$size" -lt "$gb" ]; then
			echo "$(awk "BEGIN {print $size / $mb}") MB"
		elif [ "$size" -lt "$tb" ]; then
			echo "$(awk "BEGIN {print $size / $gb}") GB"
		elif [ "$size" -lt "$pb" ]; then
			echo "$(awk "BEGIN {print $size / $tb}") TB"
		else
			echo "$(awk "BEGIN {print $size / $pb}") PB"
		fi
	fi
}

prepare_files() {
	if [ ! -d "$LOG_DIR" ]; then
		mkdir -p "$LOG_DIR"
	fi
	if [ ! -f "$APP_LOG_PATH" ]; then
		touch "$APP_LOG_PATH"
	fi
	if [ ! -f "$CORE_LOG_PATH" ]; then
		touch "$CORE_LOG_PATH"
	fi
	if [ ! -d "$TEMP_DIR" ]; then
		mkdir -p "$TEMP_DIR"
	fi
}

log() {
	echo "[$(date "+%Y-%m-%d %H:%M:%S")] [$1] $2" >> "$APP_LOG_PATH"
}

# Convert the configured log size limit into bytes.
# Honours "log.scheduled_clear_size_limit" + "log.scheduled_clear_size_limit_unit".
get_log_size_limit_bytes() {
	local limit unit
	config_get limit "log" "scheduled_clear_size_limit" 1
	config_get unit "log" "scheduled_clear_size_limit_unit" "MB"
	case "$unit" in
		B) echo "$((limit))" ;;
		KB) echo "$((limit * 1024))" ;;
		MB) echo "$((limit * 1024 * 1024))" ;;
		GB) echo "$((limit * 1024 * 1024 * 1024))" ;;
		*) echo "0" ;;
	esac
}

# Total RAM in MB.
get_mem_total_mb() {
	awk '/^MemTotal:/ { printf "%d", $2 / 1024 }' /proc/meminfo
}

# Share of the total RAM the kernel still considers available, in percent.
get_mem_available_pct() {
	awk '/^MemAvailable:/ { a = $2 } /^MemTotal:/ { t = $2 } END { if (t > 0) printf "%d", a * 100 / t }' /proc/meminfo
}

# Resident memory (MB) of a pid, empty if the process is gone.
get_pid_rss_mb() {
	local pid; pid="$1"
	[ -n "$pid" ] && [ -r "/proc/$pid/status" ] || return
	awk '/^VmRSS:/ { printf "%d", $2 / 1024 }' "/proc/$pid/status"
}

# pid of the running core, empty if not running.
get_core_pid() {
	pidof "$CORE_PROC_NAME" 2>/dev/null | awk '{print $1}'
}

# eBPF shared (LAN proxy) data-plane rewrites destination addresses into the
# 127.128.0.0/9 loopback-reserved range. The kernel treats packets in that
# range arriving on a non-loopback interface (e.g. br-lan) as martian unless
# accept_local is enabled. Writing to conf.all/conf.default only affects
# interfaces that are created afterwards, so every interface that already
# exists has to be set explicitly as well.
set_ebpf_accept_local() {
	local value; value="$1"
	sysctl -q -w net.ipv4.conf.all.accept_local="$value"
	sysctl -q -w net.ipv4.conf.default.accept_local="$value"
	local iface
	for iface in /proc/sys/net/ipv4/conf/*; do
		iface="${iface##*/}"
		[ "$iface" = "all" ] && continue
		[ "$iface" = "default" ] && continue
		[ "$iface" = "lo" ] && continue
		sysctl -q -w "net.ipv4.conf.$iface.accept_local=$value" > /dev/null 2>&1
	done
}
