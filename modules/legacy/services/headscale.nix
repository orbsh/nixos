# Headscale 自建控制面 + 内嵌 DERP 中继（服务端）
# 企业组网：本地用户 + preauthkey，无 OIDC；ban = 吊销 key / 删除节点。
# headscale 只监听 loopback，对外 TLS 由 ferron 反代；DERP HTTPS 走同入口，STUN 走 UDP。
{ config, lib, ... }:
let
  cfg = config.services.myHeadscale;
in
{
  options.services.myHeadscale = {
    enable = lib.mkEnableOption "headscale 控制面（默认关闭，启用后 headscale 服务随之拉起）";

    domain = lib.mkOption {
      type = lib.types.str;
      example = "hs.d";
      description = "控制面域名，server_url = https://<domain>，需在 ferron/Numa 配置反代到 127.0.0.1:8080";
    };

    magicDnsDomain = lib.mkOption {
      type = lib.types.str;
      example = "ts.d";
      description = "MagicDNS 节点名后缀（headscale 硬性要求与 server_url 域名不同）";
    };

    subnetCIDR = lib.mkOption {
      type = lib.types.str;
      default = "100.64.0.0/10";
      description = "Tailscale 节点 IP 分配段（Tailscale 客户端固定支持的 CGNAT 段）";
    };

    enableDerp = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "内嵌 DERP server（headscale 0.23+ 同进程，免独立 derper）";
    };

    derpPort = lib.mkOption {
      type = lib.types.port;
      default = 3478;
      description = "DERP STUN 监听端口（UDP）；DERP HTTPS 由反代暴露 /derp";
    };

    derpRegionId = lib.mkOption {
      type = lib.types.int;
      default = 999;
      description = "DERP region id，须避开官方 derp map 已占用的 id";
    };

    derpVerifyClients = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "仅注册节点可用本 DERP 中继，防未注册白嫖流量";
    };
  };

  config = lib.mkIf cfg.enable {
    services.headscale = {
      enable = true;
      # 只监听 loopback，对外由 ferron 反代 TLS
      address = "127.0.0.1";
      port = 8080;
      settings = {
        server_url = "https://${cfg.domain}";
        prefixes.v4 = cfg.subnetCIDR;
        dns = {
          magic_dns = true;
          base_domain = cfg.magicDnsDomain;
          nameservers.global = [ "1.1.1.1" "8.8.8.8" ];
        };
        derp = {
          # 只用自建 DERP，不拉官方 derp map（国内不可达）
          urls = [ ];
          paths = [ ];
          auto_update_enabled = false;
          server = {
            enabled = cfg.enableDerp;
            region_id = cfg.derpRegionId;
            region_code = "self";
            region_name = "Self-hosted DERP";
            stun_listen_addr = "0.0.0.0:${toString cfg.derpPort}";
            verify_clients = cfg.derpVerifyClients;
          };
        };
        database.type = "sqlite";
        log.level = "info";
      };
    };

    networking.firewall.allowedUDPPorts = lib.mkAfter [ cfg.derpPort ];
    # 443/tcp 由 ferron 占用并反代 headscale 与 /derp，此处不开放 8080
  };
}
