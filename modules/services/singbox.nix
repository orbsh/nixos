# sing-box 代理组件（可复用，工作站/服务器通用）
# 替换 mihomo/ladder：配置声明式进 NixOS + 易变数据放 $HOME 可手改 + SIGHUP 热更。
#
# 架构（对齐方案 memos/singbox-migration-plan.md）：
#   - 系统级 service（非 user service）——服务器无登录用户会话也要能跑
#   - 配置以 KDL 源文件管理：configDir(~/.config/singbox) 下放置 *.kdl 源文件
#     （singbox / rules / rule_set / outbounds 各段，可拆分成多个 .kdl 文件）
#   - 三个目录独立（XDG 约定）：
#     · configDir = 配置源目录（*.kdl，--config-path）。默认 ~/.config/singbox，可覆盖
#     · dataDir   = 数据目录（生成的 config.json + cache.db + 日志）。默认 ~/.local/share/singbox
#     · ruleDir   = 规则数据目录（*.srs 二进制规则，--rule-bin-path）。默认 dataDir/rule-sets
#   - ExecStartPre 用 singbox-conf 命令（writeShellScriptBin 进 systemPackages）
#     读取 configDir 下所有 *.kdl 合并(glob+flatten)生成单一 config.json 到 dataDir，然后 sing-box run -c 加载
#   - singbox-conf 命令内部经 assets/singbox-conf.nu 的 standalone generate 入口执行
#   - 热更：改 .kdl → systemctl reload（重新生成 config.json → clash API PUT /configs 进程内重载）
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
  # XDG 目录约定：configDir = 配置源（KDL，~/.config/singbox）；
  #                dataDir  = 数据（生成的 config.json + cache.db + 日志，~/.local/share/singbox）
  # 默认值直接写进选项 default（下方 options），故这里取 cfg.X 即可，无需判空。
  configDirPath = cfg.configDir;
  dataDirPath   = cfg.dataDir;
  ruleDirPath   = cfg.ruleDir;

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

  # 共享生成逻辑（ExecStartPre 与 ExecReload 同用）：
  #   1. 目录就绪；无 .kdl 源时生成全直连占位 config.kdl（服务器占位/首次）
  #   2. singbox-conf generate 读 configDirPath 所有 *.kdl 合并 → config.json 到数据目录
  #      clashApiPort 非 null 时注入 experimental.clash_api（声明式由 NixOS 管，KDL 源不掺生成物）
  singboxGen = pkgs.writeShellScript "singbox-generate" ''
    set -e
    mkdir -p ${dataDirPath} ${configDirPath} ${ruleDirPath}
    # 注: ls 无匹配返回非零，加 || true 避免 set -e 误终止
    kdls="$(ls ${configDirPath}/*.kdl 2>/dev/null || true)"
    if [ -z "$kdls" ]; then
      cat > "${configDirPath}/config.kdl" <<'KDL'
singbox {
    log level=info timestamp=#true output="singbox.log"
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
      chown ${user} "${configDirPath}/config.kdl"
    fi
    ${singboxConfPath} generate --config-path ${configDirPath} --rule-bin-path ${ruleDirPath} \
      ${lib.optionalString (cfg.clashApiPort != null) ''--clash-api "127.0.0.1:${toString cfg.clashApiPort}"''} \
      --output "${dataDirPath}/config.json"
    chown ${user} "${dataDirPath}/config.json"
  '';

in
{
  options.services.singbox = {
    listenPort = lib.mkOption {
      type = lib.types.int;
      default = 7890;
      description = "本地混合入站端口（兼容现有 http_proxy 应用）";
    };
    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "${userHome}/.local/share/singbox";
      description = "数据目录（放置生成的 config.json + cache.db + singbox.log）。默认 $HOME/.local/share/singbox（XDG_DATA_HOME）";
    };
    configDir = lib.mkOption {
      type = lib.types.path;
      default = "${userHome}/.config/singbox";
      description = "KDL 配置源目录（放置 *.kdl 源文件，--config-path）。默认 $HOME/.config/singbox";
    };
    ruleDir = lib.mkOption {
      type = lib.types.path;
      default = "${config.services.singbox.dataDir}/rule-sets";
      description = "规则数据目录（*.srs 二进制规则文件，scan-binary-ruleset 扫描生成 rule_set 声明）。默认 dataDir/rule-sets";
    };
    clashApiPort = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = 7892;
      description = "clash API（external_controller）端口。固定绑定 127.0.0.1；null = 禁用。默认 7892（避开 9090 常用端口）";
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

    # ── 数据目录 + 配置源目录 + 规则数据目录 ──
    systemd.tmpfiles.rules = [
      "d ${dataDirPath} 0755 ${user} users -"
      "d ${configDirPath} 0755 ${user} users -"
      "d ${ruleDirPath} 0755 ${user} users -"
    ];

    systemd.services.singbox = {
      description = "sing-box proxy daemon";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = user;
        # 工作目录 = 数据目录：让 sing-box 生成的 cache.db / singbox.log 落到数据目录（与 config.json 同处）
        WorkingDirectory = dataDirPath;
        # 读取 KDL 源目录(configDirPath)所有 *.kdl → 合并 → 生成 config.json 到数据目录(dataDirPath)
        ExecStartPre = singboxGen;
        # 加载生成的单一 config.json
        ExecStart = "${pkgs.sing-box}/bin/sing-box run -c ${dataDirPath}/config.json";
        # 热更：重新生成 config.json → 走 clash API 进程内重载（不断连接，不重建实例）。
        # 配置不正确时接口返回 5xx，reload 失败、旧进程旧配置继续（避免空窗），无需单独 check。
        # clashApiPort = null（禁用 API）时无热更通道，reload 直接失败退出。
        ExecReload = [
          singboxGen
          "${pkgs.curl}/bin/curl -fsS -X PUT http://127.0.0.1:${toString cfg.clashApiPort}/configs -d '{\"path\": \"${dataDirPath}/config.json\"}'"
        ];
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    # ── 网络切换自动重连（层1）：NM dispatcher（仅工作站有 NetworkManager）──
    # 仅 up 事件触发：down 时网络已断，重启无意义；up 后等 3s 网络稳定再 restart
    networking.networkmanager.dispatcherScripts = lib.mkIf (config.networking.networkmanager.enable or false) [{
      source = pkgs.writeText "singbox-nm-dispatcher" ''
        #!/bin/sh
        [ "$2" = "up" ] || [ "$2" = "vpn-up" ] || exit 0
        sleep 3
        /run/current-system/sw/bin/systemctl restart singbox.service
      '';
      type = "basic";
    }];

    # ── 网络切换自动重连（层2）：健康检查 timer（catch 静默断链/上游无响应）──
    # after 仅做启动顺序约束，不用 requires/wants：健康检查必须能在 singbox 挂掉时独立运行
    systemd.services.singbox-healthcheck = {
      description = "sing-box health check (restart on failure)";
      after = [ "singbox.service" ];
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
            flag=/run/singbox-health-fail
            n=$([ -f "$flag" ] && cat "$flag" || echo 0)
            n=$((n+1))
            if [ "$n" -ge 3 ]; then
              /run/current-system/sw/bin/systemctl restart singbox.service
              rm -f "$flag"
            else
              echo "$n" > "$flag"
            fi
          else
            rm -f /run/singbox-health-fail
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
        Persistent = true;
      };
    };
  };
}