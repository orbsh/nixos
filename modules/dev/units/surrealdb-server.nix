{ pkgs, ... }: {
  # SurrealDB 服务端（独立部署/本地调试用）
  services.surrealdb = {
    enable = true;
    package = pkgs.surrealdb.overrideAttrs (old: {
      version = "3.0.5";
      src = pkgs.fetchFromGitHub {
        owner = "surrealdb";
        repo = "surrealdb";
        rev = "v3.0.5";
        hash = "sha256-H4hKTWF8yNOKThFh/ntojmYMYb8+xzziOAL2xlkUfSM=";
      };
      cargoHash = "sha256-gGaP9hIaiv7n+Izi3X8K9YpBJtPLXANI82lJy07ZMZI=";
    });
  };
}
