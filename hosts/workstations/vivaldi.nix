{ ... }: {
  desktop.vivaldi.src = (builtins.fetchTree {
    type = "file";
    url = "file:///nix/store/v9nvql15shg3lr8l567k144a8dq8q81l-vivaldi-stable_8.0.4033.35-1_amd64.deb";
    narHash = "sha256-LAp/P2A0aga6y2fVhJU6QY2+aL5vtUuikFCOZcCa7D8=";
  }).outPath;
}
