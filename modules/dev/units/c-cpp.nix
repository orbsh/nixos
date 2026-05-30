{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    gcc
    cmake
    gnumake
    pkg-config
  ];
}
