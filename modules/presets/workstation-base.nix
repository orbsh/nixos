{ inputs, user, lib, pkgs, ... }: {
  imports = [
    # 核心系统预设 (sys, base, nix, users, network, extra, container)
    ../system/core.nix
    ../services/virt.nix               # libvirtd/virt-manager 虚拟机支持

    ../desktop/full.nix

    ../dev/fullstack.nix
    ../services/hermes-system.nix  # Hermes Agent: systemd 守护 + 全局 CLI 包裹
    ../services/harmonia.nix     # 本地二进制缓存
    ../services/ladder.nix       # Podman 代理链
    ../services/podman-apps.nix  # Podman 应用全家桶
  ];

  # ── SSD 寿命优化：临时构建缓存移入内存 ───────────
  # 避免 nixos-rebuild 在 /tmp 产生数 GB 高频临时写入磨损 SSD
  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "50%";  # 分配最大 50% 物理内存给临时盘

  # ── 用户环境配置 ──────────────────────────────────────
  home-manager.users.${user} = {
    imports = [
      ../home/desktop.nix
    ];

    # 工作站开发模式：符号链接 + git clone
    programs.nushell.developMode = lib.mkForce true;
  };

  # 主机名应由具体节点定义，而非基座
  # networking.hostName = "workstation";
}
