{ pkgs, ... }: {
  imports = [
    ./podman/network.nix
    ./podman/gitea.nix
    ./podman/miniflux.nix
    ./podman/qbittorrent.nix
    #./podman/aria2.nix
  ];
}
