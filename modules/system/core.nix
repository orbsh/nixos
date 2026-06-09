{ ... }: {
  imports = [
    ./units/sys.nix
    ./units/base.nix
    ./units/nix.nix
    ./units/users.nix
    ./units/network.nix
    ./units/extra.nix
    ./units/container.nix
    ./units/media.nix
    ./units/nushell.nix
    ./units/systemd-compliance.nix
    ./units/hardware-generic.nix
  ];
}
