{ pkgs, user, ... }: {
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
    # SSH pubkey
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK2Q46WeaBZ9aBkS3TF2n9laj1spUkpux/zObmliHUOI"
    ];
  };

  # lp 组（打印机）
  services.printing.enable = true;
}
