#!/usr/bin/ucode

'use strict';

import { cursor } from 'uci';
import { connect } from 'ubus';
import { uci_bool, uci_int, uci_array, trim_all, get_cgroups_version, get_uids } from '/etc/nikki/ucode/include.uc';

const uci = cursor();
const ubus = connect();

const config = {};

const outbound_interface = uci.get('nikki', 'mixin', 'outbound_interface');
const outbound_interface_status = ubus.call('network.interface', 'status', { 'interface': outbound_interface });
const outbound_device = outbound_interface_status?.l3_device ?? outbound_interface_status?.device ?? '';

config['log-level'] = uci.get('nikki', 'mixin', 'log_level');
config['mode'] = uci.get('nikki', 'mixin', 'mode');
config['find-process-mode'] = uci.get('nikki', 'mixin', 'match_process');
config['interface-name'] = outbound_device;
config['ipv6'] = uci_bool(uci.get('nikki', 'mixin', 'ipv6'));
config['unified-delay'] = uci_bool(uci.get('nikki', 'mixin', 'unify_delay'));
config['tcp-concurrent'] = uci_bool(uci.get('nikki', 'mixin', 'tcp_concurrent'));
config['disable-keep-alive'] = uci_bool(uci.get('nikki', 'mixin', 'disable_tcp_keep_alive'));
config['keep-alive-idle'] = uci_int(uci.get('nikki', 'mixin', 'tcp_keep_alive_idle'));
config['keep-alive-interval'] = uci_int(uci.get('nikki', 'mixin', 'tcp_keep_alive_interval'));

config['external-ui'] = uci.get('nikki', 'mixin', 'ui_path');
config['external-ui-name'] = uci.get('nikki', 'mixin', 'ui_name');
config['external-ui-url'] = uci.get('nikki', 'mixin', 'ui_url');
config['external-controller'] = uci.get('nikki', 'mixin', 'api_listen');
config['external-controller-tls'] = uci.get('nikki', 'mixin', 'api_tls_listen');
config['tls'] = {};
config['tls']['certificate'] = uci.get('nikki', 'mixin', 'api_tls_cert');
config['tls']['private-key'] = uci.get('nikki', 'mixin', 'api_tls_key');
config['tls']['ech-key'] = uci.get('nikki', 'mixin', 'api_tls_ech_key');
config['secret'] = uci.get('nikki', 'mixin', 'api_secret');

config['allow-lan'] = uci_bool(uci.get('nikki', 'mixin', 'allow_lan'));
config['port'] = uci_int(uci.get('nikki', 'mixin', 'http_port'));
config['socks-port'] = uci_int(uci.get('nikki', 'mixin', 'socks_port'));
config['mixed-port'] = uci_int(uci.get('nikki', 'mixin', 'mixed_port'));
config['redir-port'] = uci_int(uci.get('nikki', 'mixin', 'redir_port'));
config['tproxy-port'] = uci_int(uci.get('nikki', 'mixin', 'tproxy_port'));

if (uci_bool(uci.get('nikki', 'mixin', 'authentication'))) {
	config['authentication'] = [];
	uci.foreach('nikki', 'authentication', (section) => {
		if (!uci_bool(section.enabled)) {
			return;
		}
		push(config['authentication'], `${section.username}:${section.password}`);
	});
}

config['tun'] = {};
config['tun']['enable'] = uci_bool(uci.get('nikki', 'mixin', 'tun_enabled'));
config['tun']['device'] = uci.get('nikki', 'mixin', 'tun_device');
config['tun']['stack'] = uci.get('nikki', 'mixin', 'tun_stack');
config['tun']['mtu'] = uci_int(uci.get('nikki', 'mixin', 'tun_mtu'));
config['tun']['gso'] = uci_bool(uci.get('nikki', 'mixin', 'tun_gso'));
config['tun']['gso-max-size'] = uci_int(uci.get('nikki', 'mixin', 'tun_gso_max_size'));
if (uci_bool(uci.get('nikki', 'mixin', 'tun_dns_hijack'))) {
	config['tun']['dns-hijack'] = uci_array(uci.get('nikki', 'mixin', 'tun_dns_hijacks'));
}

config['dns'] = {};
config['dns']['enable'] = uci_bool(uci.get('nikki', 'mixin', 'dns_enabled'));
config['dns']['cache-algorithm'] = uci.get('nikki', 'mixin', 'dns_cache_algorithm');
config['dns']['listen'] = uci.get('nikki', 'mixin', 'dns_listen');
config['dns']['ipv6'] = uci_bool(uci.get('nikki', 'mixin', 'dns_ipv6'));
config['dns']['enhanced-mode'] = uci.get('nikki', 'mixin', 'dns_mode');
config['dns']['fake-ip-range'] = uci.get('nikki', 'mixin', 'fake_ip_range');
config['dns']['fake-ip-range6'] = uci.get('nikki', 'mixin', 'fake_ip6_range');
config['dns']['fake-ip-ttl'] = uci_int(uci.get('nikki', 'mixin', 'fake_ip_ttl'));
if (uci_bool(uci.get('nikki', 'mixin', 'fake_ip_filter'))) {
	config['dns']['fake-ip-filter'] = uci_array(uci.get('nikki', 'mixin', 'fake_ip_filters'));
}
config['dns']['fake-ip-filter-mode'] = uci.get('nikki', 'mixin', 'fake_ip_filter_mode');

config['dns']['respect-rules'] = uci_bool(uci.get('nikki', 'mixin', 'dns_respect_rules'));
config['dns']['prefer-h3'] = uci_bool(uci.get('nikki', 'mixin', 'dns_doh_prefer_http3'));
config['dns']['use-system-hosts'] = uci_bool(uci.get('nikki', 'mixin', 'dns_system_hosts'));
config['dns']['use-hosts'] = uci_bool(uci.get('nikki', 'mixin', 'dns_hosts'));
if (uci_bool(uci.get('nikki', 'mixin', 'hosts'))) {
	config['hosts'] = {};
	uci.foreach('nikki', 'hosts', (section) => {
		if (!uci_bool(section.enabled)) {
			return;
		}
		config['hosts'][section.domain_name] = uci_array(section.ip);
	});
}
if (uci_bool(uci.get('nikki', 'mixin', 'dns_nameserver'))) {
	config['dns']['default-nameserver'] = [];
	config['dns']['proxy-server-nameserver'] = [];
	config['dns']['direct-nameserver'] = [];
	config['dns']['nameserver'] = [];
	config['dns']['fallback'] = [];
	uci.foreach('nikki', 'nameserver', (section) => {
		if (!uci_bool(section.enabled)) {
			return;
		}
		push(config['dns'][section.type], ...uci_array(section.nameserver));
	})
}
if (uci_bool(uci.get('nikki', 'mixin', 'dns_proxy_server_nameserver_policy'))) {
	config['dns']['proxy-server-nameserver-policy'] = {};
	uci.foreach('nikki', 'proxy_server_nameserver_policy', (section) => {
		if (!uci_bool(section.enabled)) {
			return;
		}
		config['dns']['proxy-server-nameserver-policy'][section.matcher] = uci_array(section.nameserver);
	});
}
config['dns']['direct-nameserver-follow-policy'] = uci_bool(uci.get('nikki', 'mixin', 'dns_direct_nameserver_follow_policy'));
if (uci_bool(uci.get('nikki', 'mixin', 'dns_nameserver_policy'))) {
	config['dns']['nameserver-policy'] = {};
	uci.foreach('nikki', 'nameserver_policy', (section) => {
		if (!uci_bool(section.enabled)) {
			return;
		}
		config['dns']['nameserver-policy'][section.matcher] = uci_array(section.nameserver);
	});
}

config['sniffer'] = {};
config['sniffer']['enable'] = uci_bool(uci.get('nikki', 'mixin', 'sniffer'));
config['sniffer']['force-dns-mapping'] = uci_bool(uci.get('nikki', 'mixin', 'sniffer_sniff_dns_mapping'));
config['sniffer']['parse-pure-ip'] = uci_bool(uci.get('nikki', 'mixin', 'sniffer_sniff_pure_ip'));
if (uci_bool(uci.get('nikki', 'mixin', 'sniffer_force_domain_name'))) {
	config['sniffer']['force-domain'] = uci_array(uci.get('nikki', 'mixin', 'sniffer_force_domain_names'));
}
if (uci_bool(uci.get('nikki', 'mixin', 'sniffer_ignore_domain_name'))) {
	config['sniffer']['skip-domain'] = uci_array(uci.get('nikki', 'mixin', 'sniffer_ignore_domain_names'));
}
if (uci_bool(uci.get('nikki', 'mixin', 'sniffer_sniff'))) {
	config['sniffer']['sniff'] = {};
	config['sniffer']['sniff']['HTTP'] = {};
	config['sniffer']['sniff']['TLS'] = {};
	config['sniffer']['sniff']['QUIC'] = {};
	uci.foreach('nikki', 'sniff', (section) => {
		if (!uci_bool(section.enabled)) {
			return;
		}
		config['sniffer']['sniff'][section.protocol]['port'] = uci_array(section.port);
		config['sniffer']['sniff'][section.protocol]['override-destination'] = uci_bool(section.overwrite_destination);
	});
}

config['profile'] = {};
config['profile']['store-selected'] = uci_bool(uci.get('nikki', 'mixin', 'selection_cache'));
config['profile']['store-fake-ip'] = uci_bool(uci.get('nikki', 'mixin', 'fake_ip_cache'));

if (uci_bool(uci.get('nikki', 'mixin', 'rule_provider'))) {
	config['rule-providers'] = {};
	uci.foreach('nikki', 'rule_provider', (section) => {
		if (!uci_bool(section.enabled)) {
			return;
		}
		if (section.type == 'http') {
			config['rule-providers'][section.name] = {
				type: section.type,
				url: section.url,
				proxy: section.node,
				size_limit: section.file_size_limit,
				format: section.file_format,
				behavior: section.behavior,
				interval: section.update_interval,
			}
		} else if (section.type == 'file') {
			config['rule-providers'][section.name] = {
				type: section.type,
				path: section.file_path,
				format: section.file_format,
				behavior: section.behavior,
			}
		}
	})
}
if (uci_bool(uci.get('nikki', 'mixin', 'rule'))) {
	config['nikki-rules'] = [];
	uci.foreach('nikki', 'rule', (section) => {
		if (!uci_bool(section.enabled)) {
			return;
		}
		const rule = [ section.type, section.matcher, section.node, uci_bool(section.no_resolve) ? 'no-resolve' : null ];
		push(config['nikki-rules'], join(',', filter(rule, (item) => item != null && item != '')));
	})
}

const geoip_format = uci.get('nikki', 'mixin', 'geoip_format');
config['geodata-mode'] = geoip_format == null ? null : geoip_format == 'dat';
config['geodata-loader'] = uci.get('nikki', 'mixin', 'geodata_loader');
config['geox-url'] = {};
config['geox-url']['geosite'] = uci.get('nikki', 'mixin', 'geosite_url');
config['geox-url']['mmdb'] = uci.get('nikki', 'mixin', 'geoip_mmdb_url');
config['geox-url']['geoip'] = uci.get('nikki', 'mixin', 'geoip_dat_url');
config['geox-url']['asn'] = uci.get('nikki', 'mixin', 'geoip_asn_url');
config['geo-auto-update'] = uci_bool(uci.get('nikki', 'mixin', 'geox_auto_update'));
config['geo-update-interval'] = uci_int(uci.get('nikki', 'mixin', 'geox_update_interval'));

// eBPF 透明入站（需要带 with_ebpf 编译的 mihomo 内核）
function ebpf_device_names(networks) {
	const devices = [];

	for (let name in networks) {
		if (name == null || name == '' || index(devices, name) != -1) {
			continue;
		}
		const status = ubus.call('network.interface', 'status', { 'interface': name });
		const device = status?.l3_device ?? status?.device ?? name;
		if (device != null && device != '' && index(devices, device) == -1) {
			push(devices, device);
		}
	}

	return devices;
}

// 本机流量接管方式：cgroup 优先（需要 cgroup v2），cgroupfs-mount 环境下退回 tc
function ebpf_local_data_plane() {
	const data_plane = uci.get('nikki', 'proxy', 'ebpf_data_plane');

	if (data_plane == null || data_plane == '' || data_plane == 'auto') {
		return get_cgroups_version() == 2 ? 'cgroup' : 'tc';
	}

	return data_plane;
}

function ebpf_dns_mode() {
	const dns_mode = uci.get('nikki', 'proxy', 'ebpf_dns_mode');

	if (dns_mode != null && dns_mode != '' && dns_mode != 'auto') {
		return dns_mode;
	}

	return (uci_bool(uci.get('nikki', 'proxy', 'ipv4_dns_hijack')) ||
		uci_bool(uci.get('nikki', 'proxy', 'ipv6_dns_hijack'))) ? 'hijack' : 'off';
}

// 本机访问控制中 proxy 为 0 的用户名单转换为 uid 排除列表
function ebpf_exclude_uids() {
	const uids = [];

	uci.foreach('nikki', 'router_access_control', (access_control) => {
		if (!uci_bool(access_control['enabled']) || uci_bool(access_control['proxy'])) {
			return;
		}
		for (let uid in get_uids(uci_array(access_control['user']))) {
			if (index(uids, uid) == -1) {
				push(uids, uid);
			}
		}
	});

	return uids;
}

// 局域网访问控制转换为源地址/源 MAC 的包含或排除列表
function ebpf_lan_filters() {
	const exclude_ip = [], exclude_mac = [], include_ip = [], include_mac = [];
	let catch_all = false, include = false;

	uci.foreach('nikki', 'lan_access_control', (access_control) => {
		if (!uci_bool(access_control['enabled'])) {
			return;
		}

		const ip = uci_array(access_control['ip']);
		const mac = uci_array(access_control['mac']);
		push(ip, ...uci_array(access_control['ip6']));

		if (length(ip) == 0 && length(mac) == 0) {
			catch_all = true;
			return;
		}

		if (uci_bool(access_control['proxy'])) {
			include = true;
			push(include_ip, ...ip);
			push(include_mac, ...mac);
		} else {
			push(exclude_ip, ...ip);
			push(exclude_mac, ...mac);
		}
	});

	const result = {};

	if (include && !catch_all) {
		if (length(include_ip) > 0)
			result['include-source-cidr'] = include_ip;
		if (length(include_mac) > 0)
			result['include-mac-address'] = include_mac;
		return result;
	}

	if (length(exclude_ip) > 0)
		result['exclude-source-cidr'] = exclude_ip;
	if (length(exclude_mac) > 0)
		result['exclude-mac-address'] = exclude_mac;

	return result;
}

// 中国大陆 IP 直连：eBPF 数据面需要 rule-provider，自动生成一个 ipcidr 规则集
function ebpf_bypass_rule_set() {
	const rule_set = uci_array(uci.get('nikki', 'proxy', 'ebpf_bypass_rule_set'));

	if (length(rule_set) > 0) {
		return rule_set;
	}

	if (!uci_bool(uci.get('nikki', 'proxy', 'bypass_china_mainland_ip')) &&
	    !uci_bool(uci.get('nikki', 'proxy', 'bypass_china_mainland_ip6'))) {
		return [];
	}

	if (config['rule-providers'] == null) {
		config['rule-providers'] = {};
	}

	config['rule-providers']['nikki-ebpf-cn-ip'] = {
		type: 'http',
		url: 'https://github.com/MetaCubeX/meta-rules-dat/raw/meta/geo/geoip/cn.mrs',
		proxy: 'DIRECT',
		format: 'mrs',
		behavior: 'ipcidr',
		interval: 86400,
	};

	return [ 'nikki-ebpf-cn-ip' ];
}

function ebpf_listener() {
	const tcp = uci.get('nikki', 'proxy', 'tcp_mode') == 'ebpf';
	const udp = uci.get('nikki', 'proxy', 'udp_mode') == 'ebpf';

	if (!tcp && !udp) {
		return null;
	}

	const local_enabled = uci_bool(uci.get('nikki', 'proxy', 'router_proxy'));
	const shared_devices = ebpf_device_names(uci_array(uci.get('nikki', 'proxy', 'lan_inbound_interface')));
	const shared_enabled = uci_bool(uci.get('nikki', 'proxy', 'lan_proxy')) && length(shared_devices) > 0;

	if (!local_enabled && !shared_enabled) {
		return null;
	}

	const network = [];

	if (tcp)
		push(network, 'tcp');
	if (udp)
		push(network, 'udp');

	const ipv6 = uci_bool(uci.get('nikki', 'proxy', 'ipv6_proxy'));
	const bypass_exclude = uci_array(uci.get('nikki', 'proxy', 'reserved_ip'));
	push(bypass_exclude, ...uci_array(uci.get('nikki', 'proxy', 'reserved_ip6')));

	if (!uci_bool(uci.get('nikki', 'proxy', 'ipv4_proxy'))) {
		push(bypass_exclude, '0.0.0.0/0');
	}

	const listener = {
		name: uci.get('nikki', 'core', 'ebpf_listener_name') ?? 'ebpf-in',
		type: 'ebpf',
		network: network,
	};
	const rule_set = ebpf_bypass_rule_set();

	if (length(rule_set) > 0) {
		listener['bypass-rule-set'] = rule_set;
	}

	if (uci_bool(uci.get('nikki', 'mixin', 'tun_enabled'))) {
		listener['bypass-tun-direct'] = true;
	}

	const data_plane = local_enabled ? ebpf_local_data_plane() : null;
	const dns_mode = ebpf_dns_mode();

	if (local_enabled) {
		const local = {
			enable: true,
			'data-plane': data_plane,
			'dns-mode': dns_mode,
			ipv6: ipv6,
			'bypass-exclude': bypass_exclude,
		};
		const exclude_uid = ebpf_exclude_uids();

		if (length(exclude_uid) > 0) {
			local['exclude-uid'] = exclude_uid;
		}

		listener.local = local;
	} else {
		listener.local = { enable: false };
	}

	if (shared_enabled) {
		const shared = {
			enable: true,
			'dns-mode': dns_mode,
			ipv6: ipv6,
			'interface': shared_devices,
			'bypass-exclude': bypass_exclude,
		};
		const filters = ebpf_lan_filters();

		for (let key, value in filters) {
			shared[key] = value;
		}

		listener.shared = shared;
	} else {
		listener.shared = { enable: false };
	}

	if (uci_bool(uci.get('nikki', 'proxy', 'fake_ip_ping_hijack')) &&
	    (shared_enabled || data_plane == 'tc')) {
		listener['fakeip-icmp'] = 'reply';
	}

	return listener;
}

const ebpf = ebpf_listener();

if (ebpf != null) {
	config['nikki-listeners'] = [ ebpf ];
}

print(trim_all(config));