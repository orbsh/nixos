{ nixpkgs, commonArgs, homeManagerInput }:

{ hostDir, hostName ? null }:
nixpkgs.lib.nixosSystem {
  specialArgs = commonArgs;
  modules = [
    { nixpkgs.hostPlatform = "x86_64-linux"; }
    hostDir
    (if hostName != null then { networking.hostName = hostName; } else {})
    homeManagerInput.nixosModules.home-manager
    {
      "home-manager" = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = commonArgs;
        backupFileExtension = "hm-backup";
      };
    }
  ];
}
