#!/bin/sh
# nikki resource watchdog
#
# On OpenWrt /var is a symlink to /tmp, so /var/log - and therefore the nikki
# core log - lives on tmpfs, i.e. in RAM. A verbose core log costs RAM, and with
# log_level=debug the core logs every XTLS Vision padding packet and every DNS
# cache hit, which can be hundreds of MB of log between two runs of the (at
# best minute granular) scheduled log clear. Together with an unbounded Go heap
# this is enough to exhaust memory, pin the CPU and take the whole router
# offline.
#
# This watchdog is a cheap, always-on safety net that:
#   1. truncates the core/app log as soon as it exceeds the configured limit,
#      independently of the coarser scheduled clear cron;
#   2. restarts the core when its resident memory stays above a threshold for
#      several consecutive checks, so a leaking or runaway core can no longer
#      take the router down with it.
#
# It runs as a dedicated procd instance started by /etc/init.d/nikki, so it
# follows the service lifecycle and needs no cron entry.

[ -f /lib/functions.sh ] && . /lib/functions.sh

. /etc/nikki/scripts/include.sh

config_load nikki

config_get_bool wd_enabled "watchdog" "enabled" 1
[ "$wd_enabled" = 1 ] || exit 0

config_get wd_interval "watchdog" "interval" 30
config_get_bool wd_log_guard "watchdog" "log_size_guard" 1
config_get wd_mem_limit "watchdog" "mem_limit" 0
config_get wd_mem_floor "watchdog" "mem_available_floor" 10
config_get wd_mem_over_count "watchdog" "mem_over_count" 3

# Alarms go to the normal app log plus a persistent file, so that they survive
# the reboot that a memory exhaustion usually ends with.
guard_log() {
	log "$1" "$2"
	echo "[$(date "+%Y-%m-%d %H:%M:%S")] [$1] $2" >> "$WATCHDOG_LOG_PATH"
}

case "$wd_interval" in
	''|*[!0-9]*) wd_interval=30 ;;
esac
if [ "$wd_interval" -lt 5 ]; then
	wd_interval=5
fi

case "$wd_mem_limit" in
	''|*[!0-9]*) wd_mem_limit=0 ;;
esac

case "$wd_mem_floor" in
	''|*[!0-9]*) wd_mem_floor=10 ;;
esac

case "$wd_mem_over_count" in
	''|*[!0-9]*) wd_mem_over_count=3 ;;
esac
if [ "$wd_mem_over_count" -lt 1 ]; then
	wd_mem_over_count=1
fi

# 0 means "auto": 60% of total RAM, which is generous for a healthy core but
# still leaves the router usable if the core ever runs away.
if [ "$wd_mem_limit" -le 0 ]; then
	wd_mem_limit=$(( $(get_mem_total_mb) * 60 / 100 ))
fi

log "Watchdog" "Started (interval=${wd_interval}s, log_size_guard=$wd_log_guard, mem_limit=${wd_mem_limit}MB, mem_available_floor=${wd_mem_floor}%, mem_over_count=$wd_mem_over_count)."

over_count=0
while :; do
	sleep "$wd_interval"

	# only guard while the service is actually running
	if [ ! -f "$STARTED_FLAG_PATH" ]; then
		over_count=0
		continue
	fi

	# 1. keep the RAM backed logs within the configured size limit
	if [ "$wd_log_guard" = 1 ]; then
		limit_bytes=$(get_log_size_limit_bytes)
		if [ -n "$limit_bytes" ] && [ "$limit_bytes" -gt 0 ]; then
			for log_file in "$CORE_LOG_PATH" "$APP_LOG_PATH"; do
				if [ -f "$log_file" ] && [ "$(wc -c < "$log_file")" -ge "$limit_bytes" ]; then
					echo -n > "$log_file"
					guard_log "Watchdog" "Truncated $(basename "$log_file"), exceeded $(format_filesize "$limit_bytes")."
				fi
			done
		fi
	fi

	# 2. keep the router from running out of memory. Two independent triggers:
	#    the core growing past its limit, and the system as a whole running low
	#    on usable memory (which also catches the RAM backed logs).
	reason=""
	if [ "$wd_mem_limit" -gt 0 ]; then
		core_rss=$(get_pid_rss_mb "$(get_core_pid)")
		if [ -n "$core_rss" ] && [ "$core_rss" -ge "$wd_mem_limit" ]; then
			reason="core memory ${core_rss}MB is over the ${wd_mem_limit}MB limit"
		fi
	fi
	if [ -z "$reason" ] && [ "$wd_mem_floor" -gt 0 ]; then
		mem_avail=$(get_mem_available_pct)
		if [ -n "$mem_avail" ] && [ "$mem_avail" -le "$wd_mem_floor" ]; then
			reason="available memory is down to ${mem_avail}%"
		fi
	fi
	if [ -n "$reason" ]; then
		over_count=$((over_count + 1))
		guard_log "Watchdog" "Memory pressure: $reason, ${over_count}/${wd_mem_over_count}."
		if [ "$over_count" -ge "$wd_mem_over_count" ]; then
			over_count=0
			# free the RAM backed core log first so the new process has more
			# head room; app.log is left alone because it holds the audit trail
			echo -n > "$CORE_LOG_PATH"
			guard_log "Watchdog" "Restarting core, $reason."
			# procd supervises the core, so it is respawned automatically
			kill -TERM "$(get_core_pid)" > /dev/null 2>&1
		fi
	else
		over_count=0
	fi
done
