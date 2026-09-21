# NetBird 客户端（连自建 netbird-server）
# 各节点按需引入；注册方式：手动 `netbird-wt0 up --setup-key <key>`（setup key
# 从管理端生成，不落配置/不落 store）。
# MagicDNS：客户端内建 resolver 监听 `dnsResolverAddress`；把它注册成 numa 的
# suffix 转发（如 *.n）由引入方负责——与 tailscale 的 *.t → 100.100.100.100 同在
# profile/host 的 numa forwarding 列表里。模块不碰 numa，无 numa 的节点（server）
# 才能直接复用。
{ config, lib, ... }:
let
  cfg = config.services.myNetbird;

  # netbird 客户端 profile 里 ManagementURL 是 Go 的 url.URL，不是字符串：
  # config.d 由 encoding/json 直接解进 Config，所以必须给 url.URL 的字段形状
  # （Scheme + Host，Host 含端口、不含 scheme）。写成字符串会在守护进程启动时报
  # "cannot unmarshal string into Go struct field Config.ManagementURL of type url.URL"。
  #
  # Host 必须带端口：客户端把 url.URL.Host 原样交给 gRPC dial（client/server/server.go
  # 的 mgm.NewClient），Go 的 url.URL 不补默认端口，缺端口时守护进程只会反复报
  # "dial tcp: address <host>: missing port in address" 而连不上控制面。
  # 上游默认值同样带端口（https://api.netbird.io:443），所以这里按 scheme 补默认端口。
  mgmtUrl = builtins.match "^(https?)://([^/]+).*" cfg.managementUrl;
  mgmtUrlParts =
    if mgmtUrl == null
    then throw "services.myNetbird.managementUrl 需为 https?://host[:port][/...] 形式"
    else
      let
        scheme = builtins.elemAt mgmtUrl 0;
        authority = builtins.elemAt mgmtUrl 1;
        defaultPort = { http = "80"; https = "443"; };
      in
      {
        inherit scheme;
        host =
          if builtins.match "[^:]+:[0-9]+" authority != null
          then authority
          else "${authority}:${defaultPort.${scheme}}";
      };
in
{
  options.services.myNetbird = {
    enable = lib.mkEnableOption "netbird 客户端（默认关闭）";

    managementUrl = lib.mkOption {
      type = lib.types.str;
      example = "https://netbird.xinminghui.com";
      description = "自建 netbird-server 控制面地址（对应服务端 service.url）";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 51820;
      description = "WireGuard 监听端口（P2P 直连用，openFirewall 自动放行）";
    };

    disableDns = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        禁止 netbird 接管系统 DNS（对应客户端的 DisableDNS / `netbird up --disable-dns`）。

        默认开启：本仓节点的系统 DNS 归 numa，netbird 只保留自己那个
        `dnsResolverAddress` resolver，由 numa 按 suffix 转发进来——
        语义同 tailscale 的 `--accept-dns=false`，避免 MagicDNS 不可达时
        连本机 .d 域都解析不了。
        DisableDNS 只关「配置系统 DNS」这一步，客户端内建 resolver 照常监听。
      '';
    };

    dnsResolverAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.153";
      description = "netbird 本地 DNS resolver 监听地址（固定 loopback，供 numa 转发）";
    };
  };

  config = lib.mkIf cfg.enable {
    services.netbird = {
      # 接受控制面下发的路由（对应 tailscale 的 acceptRoutes=true）
      useRoutingFeatures = "client";
      clients.wt0 = {
        port = cfg.port;
        openFirewall = true;
        # 手动登录：不启用 setup key 自动登录
        login.enable = false;
        dns-resolver.address = cfg.dnsResolverAddress;
        # 系统 DNS 归 numa，客户端只管自己那个 resolver（见 disableDns 选项）
        config.DisableDNS = cfg.disableDns;
        # 自建控制面：写进 config.d 的 ManagementURL（url.URL 字段形状，见文件头注释）
        config.ManagementURL = {
          Scheme = mgmtUrlParts.scheme;
          Host = mgmtUrlParts.host;
        };
      };
    };
  };
}
