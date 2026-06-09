{ inputs, pkgs, lib, user, ... }: {
  # ── Nix 自身配置 ────────────────────────────────────────
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    keep-failed = false;          # 不保留构建失败的临时目录
    trusted-users = [ "root" user ];  # 允许这些用户指定 substituters 等受限设置
    substituters = [
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://cache.nixos.org"
    ];
    trusted-public-keys = [
      "harmonia-local:bF/+RpECJWbbE8W7/hu1jWRlkQqu/+cXoVrWFENmqXY="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
    builders-use-substitutes = true;
  };

  # ── systemd compliance check ──
  imports = [ ./systemd-compliance.nix ];

  # 每周自动清理未使用的包
  nix.gc = {
    automatic = lib.mkDefault true;
    dates = lib.mkDefault "weekly";
    options = lib.mkDefault "--delete-older-than 7d";
  };

  # ── direnv（进入目录自动加载 .envrc）──
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;  # Nix 集成（自动缓存 flake/devShell）
  };

  # ── nix-index（nix-locate 按文件名搜索包）──
  programs.nix-index.enable = true;

  # ── Nix 生态工具 ───────────────────────────────────────
  environment.systemPackages = with pkgs; [
    # ── NixOS 部署与安装 ──
    nixos-install-tools           # nixos-install, nixos-enter
    inputs.disko.packages.${pkgs.stdenv.hostPlatform.system}.default  # 声明式磁盘分区
    inputs.nixos-anywhere.packages.${pkgs.stdenv.hostPlatform.system}.nixos-anywhere  # 远程部署 NixOS

    # ── Nix 系统管理 ──
    nh                            # 简化 NixOS 管理（nh os switch, nh clean 等）

    # ── Nix 包管理与开发 ──
    cachix                        # Nix 缓存管理（CI/CD 加速）
    nix-init                      # 快速生成 Nix 包 / Flake 模板
    nix-update                    # 自动更新包版本和 hash

    # ── Nix 调试与可视化 ──
    nix-tree                      # 可视化依赖树
    nix-diff                      # 对比 closures 差异
    nix-index                     # 按文件名搜索包（nix-locate）
  ];

  # 修复 nh 等工具调用 sudo 时权限不足的问题
  # 强制指向系统提供的带 setuid 的 wrapper，而不是 store 里的原始二进制
  environment.sessionVariables.SUDO = "/run/wrappers/bin/sudo";
}
