# sing-box 代理组件（可复用，工作站/服务器通用）
# 替换 mihomo/ladder：配置声明式进 NixOS + 易变数据放 $HOME 可手改 + SIGHUP 热更。
#
# 架构（对齐方案 memos/singbox-migration-plan.md）：
#   - 系统级 service（非 user service）——服务器无登录用户会话也要能跑
#   - 全用 -C 配置目录（主配置也放目录里），sing-box 自动合并 ~/.config/singbox 顶层所有 *.json：
#     · config.json      主配置（log/inbounds/outbounds[direct 兜底]/route 框架）
#     · outbounds.json   出口扩展点（数组留空+注释；加代理出口在此追加，与 config 的 outbounds 拼接）
#     · rules.json       rule_set 声明扩展点（数组留空+注释；引用顶层规则数据文件）
#   - 单层目录，无子目录（-C 不递归 os.ReadDir；规则数据文件也平铺同目录，path 同目录引用）
#   - 注：sing-box 只支持 JSON/JSONC（不支持 YAML/TOML）
#   - configDir 指向 ~/.config/singbox（非 store）→ 可手改，改后 kill -HUP / systemctl reload 热更无需 rebuild
#   - 网络切换自动重连：NetworkManager dispatcher（层1）+ 健康检查 timer（层2）
#
# 用法：
#   默认 = 全直连（工作站/服务器通用，引入即起效）。
#   要代理：手改 ~/.config/singbox/outbounds.json（数组追加 socks 出口）+ rules.json（引用 rule_set）+ config.json（route 加分流/改 final）。
#   服务器占位：import 即全直连。
{ config, pkgs, lib, user, ... }:

let
  cfg = config.services.singbox;
  userHome = "/home/${user}";
  # 默认配置目录 = ~/.config/singbox（顶层 *.json 平铺自动合并；不再多包一层 conf.d）
  defaultConfigDir = "${userHome}/.config/singbox";
  configDirPath  = if cfg.configDir != null then cfg.configDir else defaultConfigDir;

  # ── 三个生成文件的内容（JSONC，upsert——仅首次生成，后手改）──
  port = toString cfg.listenPort;

  # 主配置：log + inbounds + outbounds([direct] 兜底出口) + route 框架（final=direct）
  mainJSON = ''
    {
      // 主配置框架（首次生成后可手改，kill -HUP / systemctl reload 生效）
      "log": { "level": "info", "timestamp": true },
      "inbounds": [
        { "type": "mixed", "listen": "127.0.0.1", "listen_port": ${port} }
      ],
      // direct 兜底出口：所有未命中分流规则的流量走它（直连）
      "outbounds": [
        { "type": "direct", "tag": "direct" }
      ],
      "route": {
        // 路由规则示例见下（取消注释即用）；未命中走 final（direct 兜底）
        "rules": [
          // { "rule_set": ["rule-private"], "outbound": "direct" }
          // { "rule_set": ["rule-world"],   "outbound": "proxy" }
        ],
        "final": "direct"
      }
    }
  '';

  # 出口扩展点：数组留空（direct 已在 config.json），加代理出口在此追加（拼接合并）
  outboundsJSON = ''
    {
      // 出口扩展点 —— 追加代理出口在此处（数组与 config.json 的 outbounds 拼接）。例如：
      //   { "type": "socks", "tag": "proxy", "server": "1.2.3.4", "server_port": 7890 }
      //   { "type": "http",  "tag": "http",  "server": "1.2.3.4", "server_port": 8080 }
      // 加完在 config.json / rules.json 的 route 里引用该 tag 做分流。
      "outbounds": [
      ]
    }
  '';

  # rule_set 声明：type local + path 指向 ~/.config/singbox 顶层规则数据文件（.json source 或 .srs binary）
  # 不用子目录——规则数据文件直接平铺在 ~/.config/singbox/ 下（如 private.json / world.json），path 指向同目录
  rulesJSON = ''
    {
      // 规则集声明——type local 引用 ~/.config/singbox 下数据文件（含在自动合并的 .json 之外，作为 rule_set 数据源）
      // 例如：先把分流规则写成 ~/.config/singbox/private.json、world.json（Plain RuleSet 格式），再取消注释引用：
      "route": {
        "rule_set": [
          // { "type": "local", "tag": "rule-private", "format": "source", "path": "${configDirPath}/private.json" },
          // { "type": "local", "tag": "rule-world",   "format": "source", "path": "${configDirPath}/world.json" }
        ]
      }
    }
  '';
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
      description = "配置目录（~/.config/singbox，顶层 *.json 自动合并）。null = $HOME/.config/singbox";
    };
    healthUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://www.gstatic.com/generate_204";
      description = "健康检查探活地址（连续失败触发重启）";
    };
  };

  # 引入即起效（无 enable 选项，对齐仓库 service 组件范式）
  config = {
    # 把 singbox 实际监听地址赋给共享 proxy.address —— 下游(nix/vicinae)据它决定走不走代理。
    # singbox 是本地 mixed 入站，故用 http:// 前缀。可手动覆盖为其他代理(socks5://...)
    proxy.address = lib.mkDefault "http://127.0.0.1:${toString cfg.listenPort}";

    # ── sing-box 包 ───────────────────────────────────────────
    environment.systemPackages = [ pkgs.sing-box ];

    # ── 配置目录 ──
    systemd.tmpfiles.rules = [
      "d ${userHome}/.config/singbox 0755 ${user} ${user} -"
      "d ${configDirPath} 0755 ${user} ${user} -"
    ];

    systemd.services.singbox = {
      description = "sing-box proxy daemon";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = user;
        # 首次生成三个文件（upsert：存在则跳过，不覆盖手改）
        ExecStartPre = pkgs.writeShellScript "singbox-execstartpre" ''
          mkdir -p ${userHome}/.config/singbox ${configDirPath}
          write_if_missing() {
            [ -f "$1" ] && return 0
            cat > "$1"
            chown ${user}:${user} "$1"
          }
          write_if_missing ${configDirPath}/config.json <<'JSON_C'
${mainJSON}
JSON_C
          write_if_missing ${configDirPath}/outbounds.json <<'JSON_O'
${outboundsJSON}
JSON_O
          write_if_missing ${configDirPath}/rules.json <<'JSON_R'
${rulesJSON}
JSON_R
        '';
        # 只需 -C（主配置也在目录里，自动合并）
        ExecStart = "${pkgs.sing-box}/bin/sing-box run -C ${configDirPath}";
        # 热更：先 check 校验，通过才发 SIGHUP。check 失败则该行非零 → systemd 中止，不 reload，旧进程继续（避免空窗）
        # systemd 逐行执行 ExecReload 数组，任一行失败即整体失败且不执行后续。
        ExecReload = [
          "${pkgs.sing-box}/bin/sing-box check -C ${configDirPath}"
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