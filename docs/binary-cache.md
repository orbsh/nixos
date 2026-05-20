# NixOS Binary Cache Operations

This document outlines how to expose the Nix store as a cache via HTTP or S3 for other nodes to consume. This avoids rebuilding packages on every node.

## 1. Key Generation
A private key is required to sign the cache; nodes need the public key to trust it.

```bash
# Generate key pair
nix-store --generate-binary-cache-key cache-name /tmp/private-key.pem /tmp/public-key.pem
```

*   **Private Key**: Store securely on the cache server or CI machine.
*   **Public Key**: Add to `nix.settings.trusted-public-keys` on all client nodes.

## 2. HTTP Cache (`nix-serve`)
Good for local LANs.

### Server Configuration (`configuration.nix`)
```nix
{
  services.nix-serve = {
    enable = true;
    port = 5000; # Default port
    secretKeyFile = "/path/to/private-key.pem";
  };
}
```

### Client Configuration (`flake.nix` or `configuration.nix`)
```nix
{
  nix.settings = {
    substituters = [ "http://<cache-server-ip>:5000" ];
    trusted-public-keys = [ "cache-name:public-key-here..." ];
  };
}
```

## 3. S3 / MinIO Cache
Preferred for persistence and remote access (e.g., cluster-wide cache).

### Pushing to S3
Requires `awscli` or valid AWS environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`).

```bash
# Push a specific path (e.g., /nix/store/hash-foo) or derivation result
nix copy --to 's3://bucket-name?endpoint=https://s3.your-domain.com' /nix/store/hash-foo
```

**Example: Push current system closure**
```bash
# For flake-based systems
nix copy --to 's3://nix-cache?endpoint=https://registry.s' $(nixos-rebuild build --flake .#myhost)
```

### Client Configuration
```nix
{
  nix.settings = {
    substituters = [ "s3://nix-cache?endpoint=https://registry.s" ];
    trusted-public-keys = [ "cache-name:public-key-here..." ];
  };
}
```

## 4. CI/CD Integration
In a CI pipeline (like Argo), build and push automatically:

```bash
# Build
nix build .#nixosConfigurations.myhost.config.system.build.toplevel

# Push
nix copy --to 's3://nix-cache?endpoint=https://registry.s' ./result
```
