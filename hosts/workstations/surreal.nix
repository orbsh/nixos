{ ... }: {
  imports = [ ../../modules/dev/units/surrealdb-server.nix ];

  surrealdb.server = {
    enable = true;
    version = "3.1.5";
    src = {
      url = "file:///nix/store/2fd96l0mzl01a7mjhjy73xgvll04f1gp-surreal";
      narHash = "sha256-Nr/c+kqzJ8tme32KN8FG3v6Ht/FdDbRbFvsK7CsiqdQ=";
    };
  };
}
