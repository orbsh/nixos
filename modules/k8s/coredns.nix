# CoreDNS 独立 DNS 服务配置
# 用途：为内网提供域名解析服务（与 K8s 无关）
# 说明：导入即启用，具体配置由引用方（如 dev.nix）注入
{ config, lib, pkgs, ... }:
let
  cfg = config.services.myCoredns;

  # ── 生成 hosts 插件配置 ─────────────────────────────
  hostsBlock = lib.optionalString (cfg.hosts != []) ''
    hosts {
      ${lib.concatStringsSep "\n" (map (r: "  ${r.ip} ${r.name}") cfg.hosts)}
      fallthrough
    }
  '';

  # ── 生成 template 插件配置 ──────────────────────────
  templateBlocks = lib.concatMapStrings (t: ''
    template IN A ${t.zone} {
      ${lib.concatStringsSep "\n" (map (ip: "  answer \"{{ .Name }} IN A ${ip}\"") t.answers)}
      fallthrough
    }
  '') cfg.templates;

  # ── 生成 forward 插件配置 ───────────────────────────
  forwardBlock = lib.optionalString cfg.forward.enable ''
    forward . ${lib.concatStringsSep " " cfg.forward.upstream} {
      policy ${cfg.forward.policy}
      ${lib.optionalString cfg.forward.preferUdp "prefer_udp"}
      expire ${cfg.forward.expire}
      ${lib.optionalString cfg.forward.forceTcp "force_tcp"}
      health_check ${cfg.forward.healthCheckInterval}
    }
  '';
in {
  # ── 模块选项 ─────────────────────────────────────────
  options.services.myCoredns = {
    listenAddr = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "监听地址";
    };

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 53;
      description = "监听端口";
    };

    # ── hosts 插件 ────────────────────────────────────
    hosts = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          ip = lib.mkOption { type = lib.types.str; description = "IP 地址"; };
          name = lib.mkOption { type = lib.types.str; description = "域名"; };
        };
      });
      default = [];
      description = "静态 DNS 记录";
    };

    # ── template 插件（后缀域名匹配）──────────────────
    templates = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          zone = lib.mkOption { type = lib.types.str; description = "匹配后缀（如 a 表示 *.a）"; };
          answers = lib.mkOption { type = lib.types.listOf lib.types.str; description = "解析到的 IP 列表（支持多 IP 轮询）"; };
        };
      });
      default = [];
      description = "后缀域名模板规则";
    };

    # ── forward 插件 ──────────────────────────────────
    forward = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "是否转发外部 DNS 请求";
      };

      upstream = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "223.5.5.5" "119.29.29.29" ];
        description = "上游 DNS 服务器";
      };

      policy = lib.mkOption {
        type = lib.types.enum [ "random" "round_robin" "sequential" ];
        default = "sequential";
        description = "上游选择策略";
      };

      preferUdp = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "是否优先使用 UDP";
      };

      expire = lib.mkOption {
        type = lib.types.str;
        default = "10s";
        description = "上游连接过期时间";
      };

      forceTcp = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "是否强制使用 TCP";
      };

      healthCheckInterval = lib.mkOption {
        type = lib.types.str;
        default = "5s";
        description = "健康检查间隔";
      };
    };

    cache = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "是否启用缓存";
      };
      ttl = lib.mkOption {
        type = lib.types.int;
        default = 120;
        description = "缓存 TTL（秒）";
      };
    };

    reload = lib.mkOption {
      type = lib.types.str;
      default = "6s";
      description = "配置重载间隔";
    };

    log = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "是否启用查询日志";
    };

    errors = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "是否启用错误日志";
    };

    loadbalance = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "是否启用负载均衡";
    };

    firewall = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "是否自动开放防火墙端口";
      };
    };

    disableSystemdResolved = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "是否禁用 systemd-resolved（避免 53 端口冲突）";
    };
  };

  # ── 配置实现（导入即启用）─────────────────────────────
  config = {
    services.coredns = {
      enable = true;
      config = ''
        .:53 {
          ${templateBlocks}
          ${forwardBlock}
          ${lib.optionalString cfg.cache.enable "cache ${toString cfg.cache.ttl}"}
          reload ${cfg.reload}
          ${lib.optionalString cfg.log "log"}
          ${lib.optionalString cfg.errors "errors"}
          ${lib.optionalString cfg.loadbalance "loadbalance"}
        }
      '';
    };

    # ── 关闭内置 DNS 解析服务（避免端口冲突）───────────
    services.resolved.enable = lib.mkIf cfg.disableSystemdResolved false;

    networking.firewall.allowedUDPPorts = lib.mkIf cfg.firewall.enable [ cfg.listenPort ];
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.firewall.enable [ cfg.listenPort ];
  };
}
