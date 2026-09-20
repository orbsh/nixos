# NetBird 客户端（连自建 netbird-server）
# 各节点按需引入；注册方式：手动 `netbird-wt0 up --setup-key <key>`（setup key
# 从管理端生成，不落配置/不落 store）。
# MagicDNS 与 numa 配合：模块把 netbird 本地 DNS resolver（固定 loopback 地址）
# 注册为 numa 的 suffix forwarding 上游，语义与 tailscale 的 *.t → 100.100.100.100 相同。
{ config, lib, ... }:
let
  cfg = config.services.myNetbird;
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

    # numa 只做单标签 suffix 匹配；netbird 服务端 MagicDNS zone 需配成同名单标签域
    dnsSuffix = lib.mkOption {
      type = lib.types.str;
      default = "nb";
      description = "netbird MagicDNS zone（须与服务端 DNS 设置一致），空 = 不注册 numa forwarding";
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
        # 自建控制面：default.json 的 ManagementURL 等价键，经 config.d 合入 config.json
        config.ManagementURL = cfg.managementUrl;
      };
    };

    services.numa.forwarding = lib.optionals (cfg.dnsSuffix != "") [
      { suffix = cfg.dnsSuffix; upstream = cfg.dnsResolverAddress; }
    ];
  };
}
