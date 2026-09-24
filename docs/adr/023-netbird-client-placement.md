# ADR-023: NetBird 客户端放置 — 宿主机唯一 client + Network Routes 中转

**日期**: 2026-09-24
**状态**: 已采纳

### 问题

dxserver（开发服务器，跑 k8s-dev 集群）需要被 NetBird 网络内的其他 peer 访问，且访问目标不限于宿主机本身——开发服务器随时加服务，需要能直接触达 k8s 内部的 Service/pod（ClusterIP、NodePort、pod IP），而不是企业内部固定几个应用走一次性暴露。

围绕"client 放宿主机还是放容器"出现过三个形态，需要定案。

### 排除的形态

#### 1. 只在 k8s pod 内跑 client（曾实际部署，已删）

helm chart `netbird-client`（deployment 仓库）以 `hostNetwork: true` 跑在 tunnel namespace。被否的原因有两层：

- 结构性缺陷：k8s 挂了连接全断。client 依赖集群内 kubelet/容器运行时，控制面故障时 peer 与宿主机的所有连通性一起消失，兜底只剩内网 172.178.5.123——对远程访问通道而言，可用性下限由最不可靠的宿主决定，不可接受。
- 实测问题：hostNetwork 下与宿主机原生 client（`services.myNetbird`，wt0）共处同一网络命名空间，互相拆台：抢 51820 端口（pod client 每次 startup 被迫换随机端口）、两份 nftables `table ip netbird` ACL/DNAT 规则写进同一 netns 互踩、两份 DNS DNAT 冲突，ICE 始终停在 Disconnected，所有连接回落 relay。同 netns 双 client 是配置面互踩的结构性冲突，不是参数可调和的。

（若 pod client 放弃 hostNetwork 改普通 pod 网络 + `/dev/net/tun`，上述打架消失，但 pod IP 是 CNI 内部网段，其它 peer 不可路由，需要额外路由分发；且 k8s 依赖的缺陷仍在。）

#### 2. 宿主机 + pod 双 client（待定案时的候选 B）

两个 client 各在自己的 netns，不打架；宿主机 client 保底，pod client 提供集群内直连。被否：为了"集群侧独立身份"（独立 ACL 分组、peer 级审计）引入第二个组件、第二份 setup key、第二份会漂移的配置面。开发服务器场景这个身份价值弱于运维成本。

#### 3. 只留宿主机 client + 逐个暴露服务（候选 A）

最简，但 k8s 内每个服务要 NodePort/hostPort 逐个暴露。"随时加服务"是常态，逐个暴露是持续性手工税，否。

### 决策

**宿主机保留唯一 client（`services.myNetbird`，即 netbird-wt0），k8s 侧不跑 client；集群内网段通过 NetBird Network Routes 由宿主机 client 作为 routing peer 广播。**

```
外部 peer ──p2p/relay──> dx 宿主机 nb (wt0) ──kernel forward──> cni0 ──> pod / ClusterIP / NodePort
```

- NixOS 配置：`hosts/server/netbird.nix` 保留（server 域）；`hosts/k8s-dev/default.nix` 同样引用它（dxserver 双域同机，宿主机 client 是唯一 client）。
- `netbird-client` chart（deployment 仓库）在其它 k8s 集群节点正常使用（xmh-2502）：hostNetwork 是 k8s 内跑 netbird client 的典型形态（ICE host candidate = 节点 IP，否则 CNI 网段对外部 peer 不可路由）。dx 不用它，仅因 dx 同机已有宿主机 client，双 client 同 netns 打架是 dx 特有冲突，非对 chart 的否定。
- Routing 配置用**节点级 Network Routes（旧模型）**：在管理后台 dxserver 节点详情添加 routes——podCIDR（`10.1.0.0/16`，k8s-dev 声明的 podCIDR）与 Service CIDR（`10.0.0.0/24`，kube-apiserver `--service-cluster-ip-range`）。实测有效。
- Networks（新模型）中同样配置了 network/resource/routing peer，但**未生效**：新版 dashboard 默认引导用 Networks，旧 Routes 已 deprecated（除 exit node 外），然而客户端对 Networks 模型的 routing-peer 转发通道协商不完整——0.78.2 客户端完全不认识（接受配置却不装路由、不开转发），升级 0.79.0 后 forward 链能看到转发与回包，但回程始终没有进入隧道（单向通）。节点详情的 Network Routes 走旧分发协议，下发即通。过渡期以旧模型为准，等客户端对 Networks 的支持成熟后再迁移。不落仓库（管理端状态）。
- 宿主机 `net.ipv4.ip_forward=1`（k8s 节点天然满足），转发放行由 netbird 下发的 ACL 处理。

### 失败半径

每一层挂掉只失去那一层，无连带：

| 故障 | 损失 | 兜底 |
|------|------|------|
| k8s 集群挂 | 集群内网段不可达 | 宿主机本身及所有 peer 连接不受影响 |
| 宿主机 netbird 挂 | NetBird 全部可达性 | 内网 172.178.5.123 直连 |
| 宿主机整机挂 | 一切 | （无，符合预期） |

### 后果

- 加服务零动作：ClusterIP 落在广播的 Service CIDR 内，新建即可从任何 peer 访问。
- 少一个组件、一份 setup key、一个会打架的配置面。
- 集群侧无独立 peer 身份（ACL 分组以宿主机身份生效）。开发服务器场景接受；若未来出现"需要集群侧独立身份"的真实需求，重新评估双 client（各自独立 netns）形态。
- 管理端 Network Route 是手工状态，重建控制面时需重配（与 setup key 同级的手工项）。
- 依赖客户端 ≥ 0.79（0.78.2 对 routing peer 的 Networks/route 处理均有缺陷）。客户端版本随 nixpkgs 滚动，升级需 `nh os switch`。
- 多集群互联的网段前提：各集群的 Service CIDR 与 podCIDR 必须两两不重叠（route 按 CIDR 下发，同前缀两条路由会静默错路；Service CIDR 建群后不可改）。新建集群须从未用段中分配并登记；已有集群重叠时不路由整个网段，只加具体地址/小段的 route 或走 NodePort。
