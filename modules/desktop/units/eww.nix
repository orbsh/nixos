{ pkgs, lib, ... }:
{
  environment.systemPackages = [ pkgs.eww ];

  # Deploy eww config to /etc/eww (system-wide)
  environment.etc."eww".source = ../assets/eww;
}