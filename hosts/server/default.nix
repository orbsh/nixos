# 独立服务器域：dxserver
# 返回一个单节点 Attrset
{ inputs, user, lib, dataDir, ... }:

let
  hardware = ./hardware;
in {
  server = {
    ip = "172.178.5.123";
    imports = [
      inputs.disko.nixosModules.disko
      hardware/disk.nix
      hardware/hardware-configuration.nix
      hardware/wireguard.nix
      # ./tailscale.nix   # 已退役（2026-10-19）：tailscale 全节点停用，模块归档在 modules/legacy/services/tailscale.nix
      ./netbird.nix

      # 角色预设
      ../../profiles/server.nix  # 提取出的服务器基座
    ];
  };
}
