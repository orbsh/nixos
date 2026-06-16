{ ... }: {
  imports = [ ../../modules/dev/units/surrealdb-server.nix ];

  surrealdb.server = {
    enable = true;
    version = "3.1.4";
    src = {
      url = "file:///nix/store/d3mfhyzrc4yybm4qag24hzl09dw5cpbr-surreal";
      narHash = "sha256-LAw1Qtru7+2zuDclEnPejMJcHjoJO0lKTDjFLJUJPBc=";
    };
  };
}
