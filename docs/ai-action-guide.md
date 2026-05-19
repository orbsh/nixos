# AI Action Guide

## Execute Commands on Remote Server

- Use `ssh <host> '<cmds>'` to execute commands on the server.
- **Always ask the user for `<host>` before running any remote command.**

## nixos-rebuild

- **Never run `nixos-rebuild` directly.** Always notify the user to execute it manually and wait for confirmation.

## Runtime Cleanup vs Configuration Changes

- **Cleaning up stale resources** (e.g., deleting old Jobs, Secrets, Pods): Execute `kubectl delete` directly via SSH.
- **Changing installation/deployment flow** (e.g., image prefixes, manifest URLs, service scripts): Must sync changes to NixOS config, then notify the user to run `nixos-rebuild switch`.

## Fetch SRI Hash for `fetchurl`

### Problem

`nix-prefetch-url` outputs **Nix base32** format (52 chars), but modern nixpkgs `fetchurl` requires **SRI base64** format (44 chars with `=` padding).

```
# Nix base32 (invalid for new nixpkgs):
sha256-0j3jmy3ci93afc0macq50a71a6wlp9r47bp50vc1qxx2xqivg9lw

# SRI base64 (correct):
sha256-nKa3I+6idxzYBuWuQ3K6lBsVjgIFM1UBc2qkyIavckg=
```

### Steps

1. **SSH to target server** and get the Nix base32 hash:
   ```bash
   ssh dx 'nix-prefetch-url <URL>'
   ```

2. **Get the hex SHA256** of the file:
   ```bash
   ssh dx 'curl -sL <URL> | sha256sum'
   ```

3. **Convert hex to SRI base64**:
   ```bash
   python3 -c "import base64; print('sha256-' + base64.b64encode(bytes.fromhex('<HEX_HASH>')).decode())"
   ```

### Example

```bash
# Step 1: Get base32 hash (for reference only)
ssh dx 'nix-prefetch-url https://github.com/envoyproxy/gateway/releases/download/v1.8.0/install.yaml'
# Output: 0j3jmy3ci93afc0macq50a71a6wlp9r47bp50vc1qxx2xqivg9lw

# Step 2: Get hex SHA256
ssh dx 'curl -sL https://github.com/envoyproxy/gateway/releases/download/v1.8.0/install.yaml | sha256sum'
# Output: 9ca6b723eea2771cd806e5ae4372ba941b158e0205335501736aa4c886af7248

# Step 3: Convert to SRI
python3 -c "import base64; print('sha256-' + base64.b64encode(bytes.fromhex('9ca6b723eea2771cd806e5ae4372ba941b158e0205335501736aa4c886af7248')).decode())"
# Output: sha256-nKa3I+6idxzYBuWuQ3K6lBsVjgIFM1UBc2qkyIavckg=
```

### One-liner

```bash
HEX=$(ssh dx 'curl -sL <URL> | sha256sum' | cut -d' ' -f1) && echo "sha256-$(python3 -c "import base64; print(base64.b64encode(bytes.fromhex('$HEX')).decode())")"
```
