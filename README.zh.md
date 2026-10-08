![GitHub License](https://img.shields.io/github/license/nikkinikki-org/OpenWrt-nikki?style=for-the-badge&logo=github) ![GitHub Tag](https://img.shields.io/github/v/release/nikkinikki-org/OpenWrt-nikki?style=for-the-badge&logo=github) ![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/nikkinikki-org/OpenWrt-nikki/total?style=for-the-badge&logo=github) ![GitHub Repo stars](https://img.shields.io/github/stars/nikkinikki-org/OpenWrt-nikki?style=for-the-badge&logo=github) [![Telegram](https://img.shields.io/badge/Telegram-gray?style=for-the-badge&logo=telegram)](https://t.me/nikkinikki_org)

中文 | [English](README.md)

# Nikki

在 OpenWrt 上使用 Mihomo 进行透明代理。

## 环境要求

- OpenWrt >= 24.10
- Linux Kernel >= 5.13
- firewall4

## 功能

- 透明代理 (Redirect/TPROXY/TUN/eBPF, IPv4 和/或 IPv6)
- 访问控制
- 配置文件混入
- 配置文件编辑器
- 定时重启

## 安装和更新

### A. 从软件源安装（推荐）

1. 添加源

```shell
# 只需运行一次
wget -O - https://github.com/nikkinikki-org/OpenWrt-nikki/raw/refs/heads/main/feed.sh | ash
```

2. 安装

```shell
# 你可以从 shell 执行命令安装或者从 LuCI 的`软件包`菜单安装
# for opkg
opkg install nikki
opkg install luci-app-nikki
opkg install luci-i18n-nikki-zh-cn
# for apk
apk add nikki
apk add luci-app-nikki
apk add luci-i18n-nikki-zh-cn
```

### B. 从发行版安装

```shell
wget -O - https://github.com/nikkinikki-org/OpenWrt-nikki/raw/refs/heads/main/install.sh | ash
```

## 卸载并重置

```shell
wget -O - https://github.com/nikkinikki-org/OpenWrt-nikki/raw/refs/heads/main/uninstall.sh | ash
```

## 如何使用

查看 [Wiki](https://github.com/nikkinikki-org/OpenWrt-nikki/wiki)

## 如何工作

1. 混入并更新配置文件。
2. 启动 Mihomo。
3. 设置定时重启。
4. 配置 IP 规则/路由。
5. 生成防火墙配置并应用。

注意上述步骤可能因配置而变动。

## eBPF 模式

Nikki 支持将 TCP/UDP 模式设置为 `eBPF 模式`，使用 Mihomo 的 eBPF 透明入站接管流量。与 Redirect/TPROXY/TUN 不同，eBPF 模式不需要 nftables 重定向规则、不需要 ip rule/路由、也不需要 TUN 设备，流量在内核数据面直接进入 Mihomo。

### 要求

- Mihomo 内核需要使用 `with_ebpf` 编译，例如 [liuran001/mihomo](https://github.com/liuran001/mihomo) 的 Alpha 分支产物。官方 MetaCubeX/mihomo 发行版不包含 eBPF 支持。
- Linux Kernel >= 5.13，内核需开启以下选项（ImmortalWrt/OpenWrt 官方 x86_64 内核默认已开启）：
  - `CONFIG_BPF_SYSCALL`
  - `CONFIG_CGROUP_BPF`（本机 cgroup 数据面）
  - `CONFIG_NET_CLS_ACT`、`CONFIG_NET_CLS_BPF`、`CONFIG_NET_ACT_BPF`、`CONFIG_NET_SCH_INGRESS`（TC 数据面）
- Mihomo 需要以 root 运行（Nikki 默认如此）。

### 使用

1. 将 `Proxy 配置`中的 `TCP 模式`/`UDP 模式`设置为 `eBPF 模式`，可以只设置其中一个。
2. 在 `eBPF 配置`标签页中按需调整选项。
3. 关闭 TUN（`Mixin` → `TUN 开关`），eBPF 模式下 Nikki 不会把流量导向 TUN。

Nikki 会随配置文件混入自动生成一个 `type: ebpf` 的监听器（名称由 `core.ebpf_listener_name` 指定，默认为 `ebpf-in`），同时不再生成重定向/TPROXY 的 nftables 规则、ip rule/路由和 TUN 配置。

### 选项映射

| Nikki | eBPF 监听器 |
| --- | --- |
| TCP/UDP 模式为 eBPF | `network: [tcp, udp]`（两者都为 eBPF 时为 `[tcp, udp]`） |
| 代理本机流量 | `local.enable` |
| 代理局域网流量 | `shared.enable` |
| 局域网入站接口 | `shared.interface`（自动由网络名转换为设备名，如 `lan` → `br-lan`） |
| IPv4/IPv6 代理 | `local.ipv6`、`shared.ipv6`；IPv4 代理关闭时以 `0.0.0.0/0` 直连 |
| 保留地址 (`reserved_ip`/`reserved_ip6`) | `local.bypass-exclude`、`shared.bypass-exclude` |
| 中国大陆 IP 直连 | `bypass-rule-set`（自动创建 `nikki-ebpf-cn-ip` 规则集，也可在 `eBPF 配置`中指定其他规则集） |
| IPv4/IPv6 DNS 劫持 | `dns-mode`（默认 `hijack`，可在 `eBPF 配置`中覆盖） |
| Fake-IP Ping 劫持 | `fakeip-icmp: reply` |
| 本机访问控制（`proxy` 为 0 的用户） | `local.exclude-uid` |
| 局域网访问控制（`proxy` 为 0 的 IP/MAC） | `shared.exclude-source-cidr`、`shared.exclude-mac-address` |
| `eBPF 配置` → 本机数据面 | `local.data-plane`（`auto` 时根据系统是否使用 cgroup v2 选择 `cgroup` 或 `tc`） |

### 已知限制

- `代理 TCP 端口`/`代理 UDP 端口`不被支持：eBPF 数据面只能表达直连端口（`bypass-port-range`），无法表达端口白名单。设置后流量仍会被接管，最终由规则引擎决定代理或直连。
- 本机访问控制中的 `组`/`cgroup` 条目不被支持，仅支持 `用户`。
- 局域网访问控制按包含/排除语义近似处理，与 nftables 中“按顺序匹配首条”的语义不完全一致。
- `dns-mode: hijack` 对被接管的流量全局生效，不受访问控制中 `DNS` 开关影响。
- 仅核心运行（`core_only`）模式下 Nikki 不混入配置文件，需要自行在配置文件中定义 `type: ebpf` 的监听器。
- 手动编写监听器时，`interface` 必须是设备名（如 `br-lan`），不能是网络名（如 `lan`）。

### 等效配置

Nikki 混入的监听器配置等价于（以 TCP/UDP 均为 eBPF 模式为例）：

```yaml
listeners:
  - name: ebpf-in
    type: ebpf
    network: [tcp, udp]
    bypass-rule-set: [nikki-ebpf-cn-ip]
    local:
      enable: true
      data-plane: cgroup
      dns-mode: hijack
      ipv6: true
      bypass-exclude: [10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, ...]
      exclude-uid: [453, 65534]
    shared:
      enable: true
      interface: [br-lan]
      dns-mode: hijack
      ipv6: true
      bypass-exclude: [10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, ...]
```

监听器的完整选项请参考上游文档：[eBPF Inbound](https://github.com/liuran001/mihomo/blob/Alpha/docs/ebpf-inbound.md)。

## 编译

```shell
# 添加源
echo "src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main" >> "feeds.conf.default"
# 更新并安装源
./scripts/feeds update -a
./scripts/feeds install -a
# 编译
make package/luci-app-nikki/compile
```

编译结果可以在`bin/packages/your_architecture/nikki`内找到。

## 依赖

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

## 贡献者

[![贡献者](https://contrib.rocks/image?repo=nikkinikki-org/OpenWrt-nikki)](https://github.com/nikkinikki-org/OpenWrt-nikki/graphs/contributors)

## 特别感谢

- [@ApoisL](https://github.com/apoiston)
- [@xishang0128](https://github.com/xishang0128)
