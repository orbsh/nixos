{ inputs, config, user, lib, pkgs, ... }: {
  imports = [
    # 系统层级：extra = core + 工作站扩展（层级式，core 由 extra 继承）
    ../modules/system/extra.nix

    ../modules/dev/fullstack.nix

    ../modules/desktop/full.nix

    ../modules/services/virt.nix           # libvirtd/virt-manager 虚拟机支持
    ../modules/services/hermes-system.nix  # Hermes Agent: systemd 守护 + 全局 CLI 包裹
    ../modules/services/harmonia.nix       # 本地二进制缓存
    ../modules/services/rustfs.nix
    ../modules/services/singbox.nix        # sing-box 代理组件（引入即起效，纯直连占位；替代 mihomo，listenPort 7890）
    ../modules/services/gitea.nix          # 自包含：gitea + app-net
    ../modules/services/miniflux.nix       # 自包含：miniflux + app-net
    ../modules/services/qbittorrent.nix    # 自包含：qbittorrent + app-net
    ../modules/services/ferron.nix         # Ferron 3.x 常驻服务（文件下载 + CGI 网关，port 8080）
    ../modules/services/numa.nix           # 本地 DNS + 反向代理（workstation 专用，server 用 CoreDNS）
  ];

  # 工作站更新快：按代 10 + 按时间 14d 双重清理
  nix.gc.keepGenerations = lib.mkForce 10;
  nix.gc.deleteOlderThan = lib.mkForce "14d";


  # 默认全直连；要代理出口：手改 ~/.config/singbox/outbounds.kdl 等（systemctl reload singbox 生效）。
  services.singbox = {
    # listenPort 默认 7890
    # 工作站网络会变 → 启用健康检查探活（模块默认 healthUrl 为空=不探活，这里显式设一个）。
    healthUrl = "http://connect.rom.miui.com/generate_204";
  };

  # ── Numa 本地 DNS ──────────────────────────────────────
  services.numa = {
    enable = true;
    tld = "d";                # 本机服务域名后缀：box.d / gitea.d / ...
    useDynamicConfig = false; # 纯声明式：直接读 store 静态配置（不再允许 REST API 动改，避免动态文件挡住声明式服务）
    src = {
      url = "http://box.d/nixos/numa-linux-x86_64.tar.gz";
      narHash = "sha256-a0tZ3N4Pa+kWGGvFP2XmnrG4rTDkYZbYa+2td+foH9M=";
    };

    # ── 本机 web 服务 → *.d 域名（numa 本地 DNS + 反向代理） ──
    # 注意：端口全部引用各服务模块的 port 选项，避免重复硬编码
    services = [
      { name = "box";         targetPort = config.services.ferron.port; }      # ferron：文件下载 + CGI 网关
      { name = "gitea";       targetPort = config.services.gitea.port; }       # gitea 代码托管
      { name = "miniflux";    targetPort = config.services.miniflux.port; }    # miniflux RSS 阅读器
      { name = "qbittorrent"; targetPort = config.services.qbittorrent.port; } # qbittorrent Web UI
      { name = "s3";          targetPort = config.services.rustfs.port; }      # rustfs S3 兼容 API
      { name = "rustfs";      targetPort = config.services.rustfs.consolePort; } # rustfs 管理控制台
      { name = "singbox";     targetPort = config.services.singbox.listenPort; } # singbox 代理入口
    ];
  };

  # ── Security ─────────────────────────────────────────────
  security.pki.certificateFiles = [
    ../modules/system/assets/certs/mitmproxy-ca-cert.pem
  ];

  # ── SSD 寿命优化：临时构建缓存移入内存 ───────────
  # 避免 nixos-rebuild 在 /tmp 产生数 GB 高频临时写入磨损 SSD
  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "50%";  # 分配最大 50% 物理内存给临时盘

  # 工作站开发模式：符号链接 + git clone
  programs.developMode = lib.mkForce true;

  # nix-ld：允许运行非 Nix 预编译二进制（如 Chrome、Steam）
  programs.nix-ld.enable = true;

  # 主机名应由具体节点定义，而非基座
  # networking.hostName = "workstation";
}
