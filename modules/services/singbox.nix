# sing-box 代理组件（可复用，工作站/服务器通用）
# 替换 mihomo/ladder：配置声明式进 NixOS + 易变数据放 $HOME 可手改 + SIGHUP 热更。
#
# 架构（对齐方案 memos/singbox-migration-plan.md）：
#   - 系统级 service（非 user service）——服务器无登录用户会话也要能跑
#   - 配置以 KDL 源文件管理：kdlDir(~/.config/singbox) 下放置 *.kdl 源文件
#     （singbox / rules / rule_set / outbounds 各段，可拆分成多个 .kdl 文件）
#   - 三个目录独立：
#     · configDir  = 配置输出目录（生成 config.json，sing-box run -c 加载）
#     · kdlDir     = KDL 配置源目录（*.kdl，--config-path）。默认与 configDir 相同，可拆开
#     · ruleDir    = 规则数据目录（*.srs 二进制规则，--rule-bin-path）
#   - ExecStartPre 用 singbox-conf 命令（writeShellScriptBin 进 systemPackages）
#     读取 kdlDir 下所有 *.kdl 合并(glob+flatten)生成单一 config.json 到 configDir，然后 sing-box run -c 加载
#   - singbox-conf 命令内部经 assets/singbox-conf.nu 的 standalone generate 入口执行
#   - 热更：改 .kdl → systemctl reload（先 check 后 HUP）重新生成并重载
#   - 注：sing-box 本身只支持 JSON/JSONC；KDL 只是我们的编辑/生成源，运行仍用生成的 config.json
#   - 网络切换自动重连：NetworkManager dispatcher（层1）+ 健康检查 timer（层2）
#
# 用法：
#   默认 = 全直连（工作站/服务器通用，引入即起效）：只放 singbox.kdl（log/dns/inbounds/route 框架，final=direct）。
#   要代理：在 configDir 放 outbounds.kdl（urltest/selector 聚合 + 协议节点）+ rules.kdl（rule_set 声明）+ 对应规则源。
#   服务器占位：import 即全直连。
{ config, pkgs, lib, user, ... }:

let
  cfg = config.services.singbox;
  userHome = "/home/${user}";
  defaultConfigDir = "${userHome}/.config/singbox";
  configDirPath  = if cfg.configDir != null then cfg.configDir else defaultConfigDir;
  # KDL 配置源目录：*.kdl 源文件所在处（--config-path）。
  # 默认与配置输出目录(configDirPath)相同；可单独指定为别处（如 ~/data/ladder/singbox-conf）。
  # 生成动作：读 kdlDirPath 的 *.kdl 合并 → 写 config.json 到 configDirPath。
  kdlDirPath     = if cfg.kdlDir != null then cfg.kdlDir else configDirPath;
  # 规则数据目录：*.srs 二进制规则文件（scan-binary-ruleset 扫描生成 rule_set 声明）
  # 与 configDir 独立 —— KDL 源目录不一定有 .srs，规则数据可能单独存放
  defaultRuleDir = "${userHome}/.config/singbox/rule-sets";
  ruleDirPath    = if cfg.ruleDir != null then cfg.ruleDir else defaultRuleDir;

  # KDL 合并/生成命令：singbox-conf（进 systemPackages → /run/current-system/sw/bin）
  # 内部用 assets/singbox-conf.nu，通过 standalone generate 入口读取配置目录生成 config.json
  singboxConf = pkgs.writeShellScriptBin "singbox-conf" ''
    # 仅在 stdin 有管道输入(非 tty)时才开 --stdin，避免 REPL/交互下卡住读 stdin
    # （generate 不读 stdin；kdl-to-config / outbounds-to-kdl 依赖管道 stdin 时才有必要）
    if [ -t 0 ]; then
      exec ${pkgs.nushell}/bin/nu --no-config-file ${./assets/singbox-conf.nu} "$@"
    else
      exec ${pkgs.nushell}/bin/nu --stdin --no-config-file ${./assets/singbox-conf.nu} "$@"
    fi
  '';
  singboxConfPath = "${singboxConf}/bin/singbox-conf";

  port = toString cfg.listenPort;

in
{
  options.services.singbox = {
    listenPort = lib.mkOption {
      type = lib.types.int;
      default = 7890;
      description = "本地混合入站端口（兼容现有 http_proxy 应用）";
    };
    configDir = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "配置输出目录（放置生成的 config.json）。null = $HOME/.config/singbox";
    };
    kdlDir = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "KDL 配置源目录（放置 *.kdl 源文件，--config-path）。null = 与 configDir 相同";
    };
    ruleDir = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "规则数据目录（*.srs 二进制规则文件，scan-binary-ruleset 扫描生成 rule_set 声明）。与 configDir 独立。null = $HOME/.config/singbox/rule-sets";
    };
    healthUrl = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "健康检查探活地址（连续失败触发重启）。空 = 不探活（适合服务器固定网络等不变环境）";
    };
  };

  # 引入即起效（无 enable 选项，对齐仓库 service 组件范式）
  config = {
    # 把 singbox 实际监听地址赋给共享 proxy.address —— 下游(nix/vicinae)据它决定走不走代理。
    # singbox 是本地 mixed 入站，故用 http:// 前缀。可手动覆盖为其他代理(socks5://...)
    proxy.address = lib.mkDefault "http://127.0.0.1:${toString cfg.listenPort}";

    # ── sing-box 包 + 配置生成命令（singbox-conf 进 system-path）──
    environment.systemPackages = [ pkgs.sing-box singboxConf ];

    # ── 配置输出目录 + KDL 源目录 + 规则数据目录 ──
    systemd.tmpfiles.rules = [
      "d ${userHome}/.config/singbox 0755 ${user} ${user} -"
      "d ${configDirPath} 0755 ${user} ${user} -"
      "d ${kdlDirPath} 0755 ${user} ${user} -"
      "d ${ruleDirPath} 0755 ${user} ${user} -"
    ];

    systemd.services.singbox = {
      description = "sing-box proxy daemon";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = user;
        WorkingDirectory = configDirPath;
        # 读取 KDL 源目录(kdlDirPath)所有 *.kdl → 合并 → 生成 config.json 到输出目录(configDirPath)
        ExecStartPre = pkgs.writeShellScript "singbox-execstartpre" ''
          set -e
          mkdir -p ${configDirPath} ${kdlDirPath} ${ruleDirPath}
          # 无 .kdl 源文件时生成全直连占位 config.kdl（服务器占位/首次）
          # 注: ls 无匹配返回非零，加 || true 避免 set -e 误终止
          kdls="$(ls ${kdlDirPath}/*.kdl 2>/dev/null || true)"
          if [ -z "$kdls" ]; then
            cat > "${kdlDirPath}/config.kdl" <<'KDL'
singbox {
    log level=info timestamp=#true
    inbounds {
        mixed listen="127.0.0.1" listen_port=${port}
    }
    outbounds {
        direct tag=direct
    }
    route {
        final direct
    }
}
KDL
            chown ${user} "${kdlDirPath}/config.kdl"
          fi
          # singbox-conf 命令：--config-path 读 kdlDirPath 所有 *.kdl 合并，--rule-bin-path 扫描规则数据目录 .srs
          ${singboxConfPath} generate --config-path ${kdlDirPath} --rule-bin-path ${ruleDirPath} --output "${configDirPath}/config.json"
          chown ${user} "${configDirPath}/config.json"
        '';
        # 加载生成的单一 config.json
        ExecStart = "${pkgs.sing-box}/bin/sing-box run -c ${configDirPath}/config.json";
        # 热更：先 check 校验，通过才发 SIGHUP。check 失败则该行非零 → systemd 中止，不 reload，旧进程继续（避免空窗）
        # systemd 逐行执行 ExecReload 数组，任一行失败即整体失败且不执行后续。
        ExecReload = [
          "${pkgs.sing-box}/bin/sing-box check -c ${configDirPath}/config.json"
          "${pkgs.coreutils}/bin/kill -HUP $MAINPID"
        ];
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    # ── 网络切换自动重连（层1）：NM dispatcher（仅工作站有 NetworkManager）──
    networking.networkmanager.dispatcherScripts = lib.mkIf (config.networking.networkmanager.enable or false) [{
      source = pkgs.writeText "singbox-nm-dispatcher" ''
        #!/bin/sh
        [ "$2" = "up" ] || [ "$2" = "down" ] || \
        [ "$2" = "vpn-up" ] || [ "$2" = "vpn-down" ] || exit 0
        /run/current-system/sw/bin/systemctl restart singbox.service
      '';
      type = "basic";
    }];

    # ── 网络切换自动重连（层2）：健康检查 timer（catch 静默断链/上游无响应）──
    systemd.services.singbox-healthcheck = {
      description = "sing-box health check (restart on failure)";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "singbox-healthcheck" ''
          # healthUrl 为空 = 不探活（服务器固定网络等不变环境），直接跳过
          if [ -z "${cfg.healthUrl}" ]; then
            exit 0
          fi
          if ! ${pkgs.curl}/bin/curl -fsS --connect-timeout 5 --max-time 8 \
            -x http://127.0.0.1:${toString cfg.listenPort} \
            ${cfg.healthUrl} >/dev/null 2>&1; then
            flag=/tmp/singbox-health-fail
            n=$([ -f "$flag" ] && cat "$flag" || echo 0)
            n=$((n+1))
            if [ "$n" -ge 3 ]; then
              /run/current-system/sw/bin/systemctl restart singbox.service
              rm -f "$flag"
            else
              echo "$n" > "$flag"
            fi
          else
            rm -f /tmp/singbox-health-fail
          fi
        '';
      };
    };
    systemd.timers.singbox-healthcheck = {
      description = "sing-box health check timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "2min";
      };
    };
    systemd.services.singbox-healthcheck.requires = [ "singbox.service" ];
  };
}