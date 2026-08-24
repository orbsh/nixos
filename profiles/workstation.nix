{ inputs, user, lib, pkgs, ... }: {
  imports = [
    # 系统层级：extra = core + 工作站扩展（层级式，core 由 extra 继承）
    ../modules/system/extra.nix

    ../modules/dev/fullstack.nix

    ../modules/desktop/full.nix

    ../modules/services/virt.nix           # libvirtd/virt-manager 虚拟机支持
    ../modules/services/hermes-system.nix  # Hermes Agent: systemd 守护 + 全局 CLI 包裹
    ../modules/services/harmonia.nix       # 本地二进制缓存
    ../modules/services/rustfs.nix
    ../modules/services/ladder.nix         # mihomo 代理（自包含单元）
    ../modules/services/singbox.nix        # sing-box 代理组件（引入即起效，纯直连占位）
    ../modules/services/gitea.nix          # 自包含：gitea + app-net
    ../modules/services/miniflux.nix       # 自包含：miniflux + app-net
    ../modules/services/qbittorrent.nix    # 自包含：qbittorrent + app-net
    ../modules/services/numa.nix           # 本地 DNS + 反向代理（workstation 专用，server 用 CoreDNS）
  ];

  # 工作站更新快：按代 10 + 按时间 14d 双重清理
  nix.gc.keepGenerations = lib.mkForce 10;
  nix.gc.deleteOlderThan = lib.mkForce "14d";


  # ── sing-box 代理（测试阶段）───────────────────────────
  # 端口先用 6789（避免与 mihomo 的 7890 冲突），测试完成后再切到默认 7890。
  # 默认全直连；要代理出口：手改 ~/.config/singbox/outbounds.json 等（systemctl reload singbox 生效）。
  services.singbox = {
    listenPort = 6789;   # 测试端口：避免与 mihomo 的 7890 冲突，测完改回默认
  };

  # ── Numa 本地 DNS ──────────────────────────────────────
  services.numa = {
    enable = true;
    tld = "numa";
    useDynamicConfig = true;  # 允许 REST API 动态更新配置
    src = {
      url = "file:///nix/store/l45bva8grxhv8pziwjq5c0cgm5rz31hq-numa-linux-x86_64.tar.gz";
      narHash = "sha256-mOSJdpZlZmTc7PU50ACL2lvDtywdMrOL7g8lvSqtUx0=";
    };
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
