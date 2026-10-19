# Tailscale 客户端（连自建 headscale）
# 各节点按需引入；注册用 preauthkey 或 `headscale nodes register --user <x> <key>`。
{ config, lib, ... }:
let
  cfg = config.services.myTailscale;
in
{
  options.services.myTailscale = {
    enable = lib.mkEnableOption "tailscale 客户端（默认关闭）";

    loginServer = lib.mkOption {
      type = lib.types.str;
      example = "https://hs.d";
      description = "自建 headscale 控制面地址（对应 myHeadscale.domain）";
    };

    advertiseRoutes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "10.6.6.0/24" ];
      description = "对外宣告的子网路由（subnet router）";
    };

    advertiseExitNode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "宣告为 exit node";
    };

    acceptRoutes = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "接受其他节点宣告的子网路由";
    };

    acceptDns = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "接受控制面下发的 MagicDNS 配置";
    };

    ssh = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "启用 tailscale ssh";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      openFirewall = true;
      useRoutingFeatures = lib.mkMerge [
        (lib.mkIf (cfg.advertiseRoutes != [ ] || cfg.advertiseExitNode) "server")
        (lib.mkIf cfg.acceptRoutes "client")
      ];
      extraUpFlags =
        [ "--login-server=${cfg.loginServer}" ]
        ++ lib.optionals (cfg.advertiseRoutes != [ ]) [
          "--advertise-routes=${lib.concatStringsSep "," cfg.advertiseRoutes}"
        ]
        ++ lib.optional cfg.advertiseExitNode "--advertise-exit-node"
        ++ lib.optional cfg.acceptRoutes "--accept-routes"
        ++ lib.optional (!cfg.acceptDns) "--accept-dns=false"
        ++ lib.optional cfg.ssh "--ssh";
    };
  };
}
