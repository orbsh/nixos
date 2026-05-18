{ pkgs, lib, config, ... }:

let
  cfg = config.dev.k8s;
in {
  options.dev.k8s.enable = lib.mkEnableOption "Kubernetes & 容器管理工具";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      kubectl
      kubernetes-helm
    ];
  };
}
