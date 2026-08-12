{ pkgs, ... }: {
  networking = {
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 2222 6443 ];
    };
  };

  # 网络配置相关工具（诊断类工具见 extra.nix）
  environment.systemPackages = with pkgs; [
    openresolv
    nftables
  ];
}
