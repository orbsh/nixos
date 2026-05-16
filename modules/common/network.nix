{ pkgs, ... }: {
  networking = {
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 2222 6443 ];
    };
    };

  # 网络诊断与管理工具
  environment.systemPackages = with pkgs; [
    netcat
    openresolv
  ];
}