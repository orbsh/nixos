{ pkgs, ... }: {
  users.users.master = {
    isNormalUser = true;
    shell = pkgs.bash;
    # 密码 mkpasswd -m yescrypt my-password
    hashedPassword = "$y$j9T$N8zsqdX1UXaCreKNDa1Le0$xzuUsYXUlkIheSCKdEn8ysxOkhO0r2bI6JMBhh/5n92";
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
