{ inputs, user, lib, pkgs, ... }: {
  imports = [
    # 核心系统预设 (sys, base, nix, users, network, extra, container)
    ../system/core.nix
    ../system/units/hardware-generic.nix  # 通用硬件配置
    ../system/units/vm.nix            # libvirtd/virt-manager 虚拟机支持

    ../desktop/full.nix

    ../dev/fullstack.nix
    ../flake-srv/hermes-system.nix  # Hermes Agent: systemd 守护 + 全局 CLI 包裹
  ];

  # ── 输入法 ──
  rime.octagram.enable = true;

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
