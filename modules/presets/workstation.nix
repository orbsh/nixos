{ inputs, user, lib, pkgs, ... }: {
  imports = [
    # 核心系统预设 + Home Manager 配置
    ../system/core.nix
    ../system/home.nix           # 基础 HM（nvim、git、shell）
    ../system/extra.nix     # 工作站扩展（helix 等）

    ../services/virt.nix               # libvirtd/virt-manager 虚拟机支持

    ../desktop/full.nix
    ../desktop/home.nix

    ../dev/fullstack.nix
    ../services/hermes-system.nix  # Hermes Agent: systemd 守护 + 全局 CLI 包裹
    ../services/harmonia.nix     # 本地二进制缓存
    ../services/ladder.nix       # Podman 代理链
    ../services/podman-apps.nix  # Podman 应用全家桶
    ../services/numa.nix         # 本地 DNS + 反向代理（workstation 专用，server 用 CoreDNS）
  ];

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

  # ── SSD 寿命优化：临时构建缓存移入内存 ───────────
  # 避免 nixos-rebuild 在 /tmp 产生数 GB 高频临时写入磨损 SSD
  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "50%";  # 分配最大 50% 物理内存给临时盘

  # 工作站开发模式：符号链接 + git clone
  programs.developMode = lib.mkForce true;

  # nix-ld：允许运行非 Nix 预编译二进制（如 jcode、Chrome、Steam）
  programs.nix-ld.enable = true;

  # 主机名应由具体节点定义，而非基座
  # networking.hostName = "workstation";
}
