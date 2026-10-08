![GitHub License](https://img.shields.io/github/license/nikkinikki-org/OpenWrt-nikki?style=for-the-badge&logo=github) ![GitHub Tag](https://img.shields.io/github/v/release/nikkinikki-org/OpenWrt-nikki?style=for-the-badge&logo=github) ![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/nikkinikki-org/OpenWrt-nikki/total?style=for-the-badge&logo=github) ![GitHub Repo stars](https://img.shields.io/github/stars/nikkinikki-org/OpenWrt-nikki?style=for-the-badge&logo=github) [![Telegram](https://img.shields.io/badge/Telegram-gray?style=for-the-badge&logo=telegram)](https://t.me/nikkinikki_org)

English | [中文](README.zh.md)

# Nikki

Transparent Proxy with Mihomo on OpenWrt.

## Prerequisites

- OpenWrt >= 24.10
- Linux Kernel >= 5.13
- firewall4

## Feature

- Transparent Proxy (Redirect/TPROXY/TUN/eBPF, IPv4 and/or IPv6)
- Access Control
- Profile Mixin
- Profile Editor
- Scheduled Restart

## Install & Update

### A. Install From Feed (Recommended)

1. Add Feed

```shell
# only needs to be run once
wget -O - https://github.com/nikkinikki-org/OpenWrt-nikki/raw/refs/heads/main/feed.sh | ash
```

2. Install

```shell
# you can install from shell or `Software` menu in LuCI
# for opkg
opkg install nikki
opkg install luci-app-nikki
opkg install luci-i18n-nikki-zh-cn
# for apk
apk add nikki
apk add luci-app-nikki
apk add luci-i18n-nikki-zh-cn
```

### B. Install From Release

```shell
wget -O - https://github.com/nikkinikki-org/OpenWrt-nikki/raw/refs/heads/main/install.sh | ash
```

## Uninstall & Reset

```shell
wget -O - https://github.com/nikkinikki-org/OpenWrt-nikki/raw/refs/heads/main/uninstall.sh | ash
```

## How To Use

See [Wiki](https://github.com/nikkinikki-org/OpenWrt-nikki/wiki)

## How does it work

1. Mixin and Update profile.
2. Run mihomo.
3. Set scheduled restart.
4. Set ip rule/route
5. Generate nftables and apply it.

Note that the steps above may change base on config.

## eBPF Mode

Nikki can use the Mihomo eBPF transparent inbound by setting `TCP Mode`/`UDP Mode` to `eBPF Mode`. Unlike Redirect/TPROXY/TUN, eBPF mode does not need nftables redirect rules, ip rules/routes or a TUN device, traffic is taken over directly in the kernel data plane.

### Requirements

- The Mihomo core must be built with the `with_ebpf` tag, e.g. releases from [liuran001/mihomo](https://github.com/liuran001/mihomo) (Alpha branch). The official MetaCubeX/mihomo releases do not include eBPF support.
- Linux Kernel >= 5.13, with `CONFIG_BPF_SYSCALL`, `CONFIG_CGROUP_BPF` (cgroup data plane) and `CONFIG_NET_CLS_ACT`/`CONFIG_NET_CLS_BPF`/`CONFIG_NET_ACT_BPF`/`CONFIG_NET_SCH_INGRESS` (TC data plane).
- The core must run as root (Nikki does so by default).

### Usage

1. Set `TCP Mode` and/or `UDP Mode` to `eBPF Mode` in the `Proxy Config` tab.
2. Tune the options in the `eBPF Config` tab if needed.
3. Turn off TUN, it is not used to hijack traffic in eBPF mode.

Nikki generates an eBPF listener (named by `core.ebpf_listener_name`, `ebpf-in` by default) while mixing the profile, and no longer generates redirect/TPROXY nftables rules, ip rules/routes or TUN related settings.

### Mapping

| Nikki | eBPF Listener |
| --- | --- |
| TCP/UDP mode | `network` |
| Router Proxy | `local.enable` |
| LAN Proxy | `shared.enable` |
| LAN Inbound Interface | `shared.interface` (logical networks are resolved to devices, e.g. `lan` → `br-lan`) |
| IPv4/IPv6 Proxy | `local.ipv6`, `shared.ipv6` (all IPv4 is bypassed via `0.0.0.0/0` when IPv4 Proxy is off) |
| Reserved IP (`reserved_ip`/`reserved_ip6`) | `bypass-exclude` |
| Bypass China Mainland IP | `bypass-rule-set` (a `nikki-ebpf-cn-ip` rule set is created automatically) |
| DNS Hijack | `dns-mode` (`hijack` by default, can be overridden in the `eBPF Config` tab) |
| Fake-IP Ping Hijack | `fakeip-icmp: reply` |
| Router Access Control (users with `proxy` 0) | `local.exclude-uid` |
| LAN Access Control (IP/MAC with `proxy` 0) | `shared.exclude-source-cidr`, `shared.exclude-mac-address` |
| `eBPF Config` → Local Data Plane | `local.data-plane` (`auto` resolves to `cgroup` or `tc` depending on cgroup v2 availability) |

### Limitations

- `Proxy TCP/UDP DPort` is not supported: the eBPF data plane only accepts a bypass port list, a port allow list cannot be expressed. Traffic is still taken over and the rule engine decides between proxy and direct.
- `group`/`cgroup` entries of the router access control are not supported, only `user`.
- LAN access control is approximated with include/exclude semantics, which is not identical to the ordered first match semantics of nftables.
- `dns-mode: hijack` applies to every intercepted flow, it is not affected by the `DNS` switch of the access control entries.
- With `core_only` enabled Nikki does not mix the profile, the `type: ebpf` listener has to be defined in the profile manually.
- A manually written listener has to use device names (e.g. `br-lan`) for `interface`, not logical network names (e.g. `lan`).

See [eBPF Inbound](https://github.com/liuran001/mihomo/blob/Alpha/docs/ebpf-inbound.md) for the full listener documentation.

## Compilation

```shell
# add feed
echo "src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main" >> "feeds.conf.default"
# update & install feeds
./scripts/feeds update -a
./scripts/feeds install -a
# make package
make package/luci-app-nikki/compile
```

The package files will be found under `bin/packages/your_architecture/nikki`.

## Dependencies

- ca-bundle
- curl
- yq
- firewall4
- ip-full
- kmod-inet-diag
- kmod-nft-socket
- kmod-nft-tproxy
- kmod-tun
- kmod-dummy

## Contributors

[![Contributors](https://contrib.rocks/image?repo=nikkinikki-org/OpenWrt-nikki)](https://github.com/nikkinikki-org/OpenWrt-nikki/graphs/contributors)

## Special Thanks

- [@ApoisL](https://github.com/apoiston)
- [@xishang0128](https://github.com/xishang0128)
