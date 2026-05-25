{ pkgs, user, ... }: {
  users.users.${user} = {
    isNormalUser = true;
    shell = pkgs.bash;
    # 密码 mkpasswd -m yescrypt "qwer"
    hashedPassword = "$y$j9T$eHkiXr76s0VRdWQo5DZm5/$pPYnU83oUkbQ8xcYjo6n8jvBxNevWZRoR/5PyQdpnF1";
    extraGroups = [
      "wheel"
      "lp"
      "podman"
    ];
    # 把你的 SSH 公钥放这里
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK2Q46WeaBZ9aBkS3TF2n9laj1spUkpux/zObmliHUOI"
    ];
  };

  # lp 组（打印机）
  services.printing.enable = true;
}
