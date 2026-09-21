# NetBird 客户端（连自建 netbird-server）
# 各节点按需引入；注册方式：手动 `netbird-wt0 up --setup-key <key>`（setup key
# 从管理端生成，不落配置/不落 store）。
# MagicDNS 与 numa 配合：模块把 netbird 本地 DNS resolver（固定 loopback 地址）
# 注册为 numa 的 suffix forwarding 上游，语义与 tailscale 的 *.t → 100.100.100.100 相同。
{ config, lib, ... }:
let
  cfg = config.services.myNetbird;

  # netbird 客户端 profile 里 ManagementURL 是 Go 的 url.URL，不是字符串：
  # config.d 由 encoding/json 直接解进 Config，所以必须给 url.URL 的字段形状
  # （Scheme + Host，Host 含端口、不含 scheme）。写成字符串会在守护进程启动时报
  # "cannot unmarshal string into Go struct field Config.ManagementURL of type url.URL"。
  mgmtUrl = builtins.match "^(https?)://([^/]+).*" cfg.managementUrl;
  mgmtUrlParts =
    if mgmtUrl == null
    then throw "services.myNetbird.managementUrl 需为 https?://host[:port][/...] 形式"
    else {
      scheme = builtins.elemAt mgmtUrl 0;
      host = builtins.elemAt mgmtUrl 1;
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

    # numa 只做单标签 suffix 匹配；自定义域一律单字母，故服务端账号的
    # custom peer DNS domain 也须设成同一个字母
    dnsSuffix = lib.mkOption {
      type = lib.types.str;
      default = "n";
      description = "netbird MagicDNS zone（须与服务端账号的 custom peer DNS domain 一致），空 = 不注册 numa forwarding";
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
        # 自建控制面：写进 config.d 的 ManagementURL（url.URL 字段形状，见文件头注释）
        config.ManagementURL = {
          Scheme = mgmtUrlParts.scheme;
          Host = mgmtUrlParts.host;
        };
      };
    };

    services.numa.forwarding = lib.optionals (cfg.dnsSuffix != "") [
      { suffix = cfg.dnsSuffix; upstream = cfg.dnsResolverAddress; }
    ];
  };
}
