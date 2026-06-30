{ ... }: {
  imports = [ ../../modules/dev/units/surrealdb-server.nix ];

  surrealdb.server = {
    enable = true;
    version = "3.1.5";
    src = {
      url = "file:///nix/store/2fd96l0mzl01a7mjhjy73xgvll04f1gp-surreal";
      narHash = "sha256-6jDBX0C2UpDKR0jxskBfFoiGkXwKo3CQR98YQFNMweg=";
    };
  };
}
