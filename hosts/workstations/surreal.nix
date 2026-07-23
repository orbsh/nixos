{ ... }: {
  imports = [ ../../modules/dev/units/surrealdb-server.nix ];

  surrealdb.server = {
    enable = true;
    version = "3.2.0";
    tarball = {
      url = "file:///home/master/pub/Application/Linux/surreal-v3.2.0.linux-amd64.tgz";
      sha256 = "1j8lwl1j3iqp79byx4f6im0d6pnvk3xq4js14lzk328agqfhvd5z";
    };
  };
}
