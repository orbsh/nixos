{ pkgs, ... }: {
  imports = [ ./units/network.nix ./units/mihomo.nix ./units/gitea.nix ./units/miniflux.nix ];
}
