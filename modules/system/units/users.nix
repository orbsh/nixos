{ pkgs, user, sshPublicKey, ... }: {
  users.users.${user} = {
    isNormalUser = true;
    shell = pkgs.bash;
    # mkpasswd -m yescrypt "qwer"
    hashedPassword = "$y$j9T$LuChS39drFFK0G9w05zzW1$ni887.E/FpNqKVqlAimC5uAUrtcytrZwgHhw7280fN0";
    extraGroups = [
      "wheel"
      "lp"
      "podman"
    ];
    openssh.authorizedKeys.keys = [ sshPublicKey ];
  };

  # lp 组（打印机）
  services.printing.enable = true;
}
