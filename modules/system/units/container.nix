# 容器通用配置（Podman + 存储）
{ pkgs, lib, config, ... }:
{
  # ── 容器镜像仓库配置（/etc/containers/registries.conf）──
  # Registries config moved to cluster-specific configuration.
  # environment.etc."containers/registries.conf".text = ...;

  # ── Podman ───────────────────────────────────────────────
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;   # `docker` -> `podman` alias
    dockerSocket.enable = true;  # 开发工具（如 Devcontainers）需要读取此套接字
    defaultNetwork.settings.dns_enabled = true;
  };


  # ── containers.conf ───────────────────────────────────
  virtualisation.containers.containersConf.settings = {
    engine.multi_image_archive = true;
  };

  # Podman storage 配置（系统级多用户共享路径，与 Containerd 隔离避免锁冲突）
  environment.etc."containers/storage.conf".text = lib.mkForce ''
    [storage]
    driver = "overlay"
    runroot = "/run/containers/storage"
    graphroot = "/var/lib/containers/storage"
  '';
  # ── 用户环境变量（容器相关）─────────────────────────────
  # 为用户环境设置 DOCKER_HOST，让某些工具以为在用 Docker
  environment.sessionVariables = {
    DOCKER_HOST = "unix:///run/user/1000/podman/podman.sock";
  };

  # ── Container Image Tools（仅在 podman 启用时安装）────
  environment.systemPackages = lib.mkIf config.virtualisation.podman.enable (with pkgs; [
    buildah
    skopeo
  ]);

  # ── OCI 镜像构建（nix2container，在 flake.nix 的 packages 输出中使用）──
  # nix2container 是 flake 函数库，不是 CLI 工具，无需安装到 systemPackages
  # 用法示例（在 flake.nix 中添加）：
  #   packages.x86_64-linux.my-image =
  #     nix2container.lib.x86_64-linux.buildImage {
  #       name = "my-image"; tag = "latest";
  #       fromImage = pkgs.dockerTools.pullImage { ... };
  #       copyToRoot = pkgs.buildEnv { ... };
  #     };
  # 构建: nix build .#my-image
  # 推送: skopeo copy docker-archive:result docker:registry:tag
}
