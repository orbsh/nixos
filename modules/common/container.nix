{ pkgs, lib, config, ... }:
let
  registriesData = import ../../config/registries.nix;
in {
  # ── 容器镜像仓库配置（/etc/containers/registries.conf）──
  environment.etc."containers/registries.conf".text = lib.mkForce (
    import ../../lib/registries-gen.nix { inherit lib; cfg = registriesData; }
  );

  # ── Podman ───────────────────────────────────────────────
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;   # `docker` -> `podman` alias
    dockerSocket.enable = true;  # 开发工具（如 Devcontainers）需要读取此套接字
    defaultNetwork.settings.dns_enabled = true;
  };


  # Podman storage 配置（路径放在 /root 下）
  environment.etc."containers/storage.conf".text = lib.mkForce ''
    [storage]
    driver = "overlay"
    runroot = "/root/.local/share/containers/storage/runroot"
    graphroot = "/root/.local/share/containers/storage"
  '';
  # ── Container Image Tools（仅在 podman 启用时安装）────
  environment.systemPackages = lib.mkIf config.virtualisation.podman.enable (with pkgs; [
    buildah
    skopeo
  ]);
}
