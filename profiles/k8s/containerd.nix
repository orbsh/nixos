# Containerd 容器运行时配置
{ config, lib, pkgs, ... }:
let
  # registriesData is now cluster-specific; handled by host configuration.
  containerdRegistryDir = "/etc/containerd/certs.d";
in {
  # ── 启用 Containerd ─────────────────────────────────────
  virtualisation.containerd.enable = true;
  # socket 组权限：允许 containerd 组用户免 sudo 访问
  # 注意：containerd 自己创建 socket，需用 ExecStartPost 修改权限
  users.groups.containerd = {};
  systemd.services.containerd.serviceConfig.ExecStartPost = ''
    ${pkgs.coreutils}/bin/chgrp containerd /run/containerd/containerd.sock \
    ; ${pkgs.coreutils}/bin/chmod 660 /run/containerd/containerd.sock
  '';
  # 自动将所有 normal users 加入 containerd 组
  # 注意：不能直接读 config.users.users 再写 users.users（会无限递归）
  # 改为设置 group members，通过读取 config.users.users 的 normal users
  users.groups.containerd.members = lib.attrNames (
    lib.filterAttrs (name: user: user.isNormalUser or false) config.users.users
  );

  # 设置环境变量，让 nerdctl 使用系统级 containerd（而非 rootless）
  environment.variables.CONTAINERD_ADDRESS = "/run/containerd/containerd.sock";

  # ── 禁用 podman（Containerd 模式下不需要）───────────────
  virtualisation.podman.enable = lib.mkForce false;

  # CLI 工具（nerdctl 兼容 Docker 命令）─────────────────
  # 用 wrapper 固定 --address 参数，避免 rootless 检测报错
  environment.systemPackages = [
    pkgs.containerd
    (pkgs.writeShellScriptBin "nerdctl" ''
      exec ${pkgs.nerdctl}/bin/nerdctl --address /run/containerd/containerd.sock "$@"
    '')
  ];

  # ── Containerd 运行时设置 ───────────────────────────────
  # ── 镜像仓库配置（containerd v2 新格式：config_path）──
  # CRI 插件必须显式指定 config_path 才能读取 hosts.toml
  # Hosts toml generation moved to cluster-specific config.
  virtualisation.containerd.settings = {
    plugins."io.containerd.grpc.v1.cri" = {
      sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.9";

      # ── CNI 网络插件配置 ──────────────────────────────
      cni.conf_dir = "/etc/cni/net.d";
      cni.bin_dir = "/opt/cni/bin";

      # ── 镜像仓库配置（containerd v2 新格式：config_path）──
      # CRI 插件必须显式指定 config_path 才能读取 hosts.toml
      registry.config_path = "/etc/containerd/certs.d";
    };
  };
}
