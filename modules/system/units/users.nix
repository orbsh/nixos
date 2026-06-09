{ pkgs, user, sshPublicKey, hashedPassword, ... }: {
  users.users.${user} = {
    isNormalUser = true;
    shell = pkgs.bash;
    inherit hashedPassword;
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
