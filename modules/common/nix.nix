{ inputs, pkgs, lib, ... }: {
  # ── Nix 自身配置 ────────────────────────────────────────
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    substituters = [
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://cache.nixos.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
    builders-use-substitutes = true;
  };

  # ── systemd compliance check ──
  imports = [ ../../lib/systemd-compliance.nix ];

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
    inputs.nixos-anywhere.packages.${pkgs.stdenv.hostPlatform.system}.nixos-anywhere  # 远程部署 NixOS

    # ── Nix 系统管理 ──
    nh                            # 简化 NixOS 管理（nh os switch, nh clean 等）

    # ── Nix 包管理与开发 ──
    cachix                        # Nix 缓存管理（CI/CD 加速）
    nix-init                      # 快速生成 Nix 包 / Flake 模板
    nix-update                    # 自动更新包版本和 hash

    # ── Nix 调试与可视化 ──
    nix-tree                      # 可视化依赖树
    nix-output-monitor            # 构建进度条（nom-build 代替 nix build）
    nix-diff                      # 对比 closures 差异
    nix-index                     # 按文件名搜索包（nix-locate）
  ];
}
