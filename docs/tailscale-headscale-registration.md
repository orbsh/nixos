# Tailscale/Headscale 注册流程

自建 headscale 部署在阿里云 K8s `tunnel` 命名空间，控制面 `https://headscale.xinminghui.com`。客户端节点（orbit / dxserver / …）通过 preauthkey 注册。注册流程的关键点：**服务端建用户 + 发 key，客户端 up**，两端分属不同的操作环境（headscale 在 K8s，客户端在各自机器）。

## 服务端（headscale，通过 kubectl）

```bash
# 1. 建用户（每台节点一个用户，名字 = 节点名）
kubectl exec deploy/headscale -n tunnel -- headscale users create <节点名>

# 2. 列出用户拿 user ID（users list 输出第一列）
kubectl exec deploy/headscale -n tunnel -- headscale users list

# 3. 生成 preauthkey（--user 传数字 ID；--reusable 可重复用；有效期按需）
kubectl exec deploy/headscale -n tunnel -- headscale preauthkeys create --user <ID> --reusable --expiration 90d
# 输出 hskey-auth-... 即 authkey

# 4. （注册后）查看节点
kubectl exec deploy/headscale -n tunnel -- headscale nodes list
```

注意：`--user` 只认数字 ID，传用户名会报 `strconv.ParseUint` 错误。

## 客户端（NixOS 节点）

节点侧统一走 `modules/services/tailscale.nix`（`services.myTailscale`）。启用方式：节点目录下建 `tailscale.nix` 引入模块（参考 `hosts/server/tailscale.nix`），并在节点 `default.nix` 的 imports 里加上。

```nix
services.myTailscale = {
  enable = true;
  loginServer = "https://headscale.xinminghui.com";
  acceptDns = false;  # 桌面机/有本机 DNS 的节点必须关，见下
};
```

`acceptDns = false` 的原因：tailscale 默认接管 resolv.conf 指向 MagicDNS stub（100.100.100.100），DERP 断连时（headscale 不可达）连本机服务的域名解析都会失败。桌面机 DNS 必须留在 numa。

switch 之后执行注册：

```bash
sudo tailscale up --accept-dns=false \
  --login-server=https://headscale.xinminghui.com \
  --authkey=<hskey-auth-...>
```

`extraUpFlags` 已带 login-server，但显式传最稳（尤其客户端曾有官方 Tailscale 登录状态时——ControlURL 残留会导致 key 被官方服务器拒收，报 `invalid key: unable to validate API key`，此时需 `sudo tailscale logout` 清状态再 up）。

## 验证

```bash
tailscale status        # 本机拿到 100.64.x.x，无 health warning
tailscale ping <对端>    # 节点间连通
```

服务端 `headscale nodes list` 应看到该节点，Connected=true。

## 反代注意（headscale 侧已配置，勿动）

Istio gateway 需透传三种 WebSocket 升级类型，已通过 EnvoyFilter（headscale chart 内置）解决：`DERP`（/derp 中继）、`tailscale-control-protocol`（/ts2021 控制）、`websocket`。若换反代方案，需重新确认这三类的 Upgrade 头透传 + POST 升级放行，否则客户端注册/中继会 403 upgrade_failed。
