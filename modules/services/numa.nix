# Numa: local DNS resolver + reverse proxy for workstation
# Replaces CoreDNS on workstation (CoreDNS stays on server for K8s)
# Import only in workstation preset, never on server/k8s
{ pkgs, lib, config, ... }:
let
  cfg = config.services.numa;

  # Static (declarative) config — Nix store, read-only
  staticConfig = pkgs.writeText "numa.toml" ''
    [server]
    bind_addr = "127.0.0.1:53"
    api_port = 5380
    data_dir = "${cfg.dataDir}"

    [upstream]
    mode = "forward"
    address = [ ${lib.concatStringsSep ", " (map (d: ''"${d}"'') cfg.upstreamDns)} ]
    fallback = [ "8.8.8.8", "1.1.1.1" ]

    [cache]
    max_entries = 100000
    min_ttl = 60
    max_ttl = 86400

    [proxy]
    enabled = true
    port = 80
    tls_port = 443
    tld = "${cfg.tld}"
    bind_addr = "127.0.0.1"

    [mobile]
    enabled = false
  '';

  # Dynamic config path — Numa REST API can write here at runtime
  configFile = "${cfg.dataDir}/numa.toml";

  # Pre-built binary from GitHub releases
  srcPath = (builtins.fetchTree {
    type = "file";
    inherit (cfg.src) url narHash;
  }).outPath;
in {
  options.services.numa = {
    enable = lib.mkEnableOption "Numa local DNS resolver and reverse proxy";

    tld = lib.mkOption {
      type = lib.types.str;
      default = "numa";
      description = "Local TLD for .numa domains";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/numa";
      description = "Numa data directory (TLS CA, certs, dynamic config)";
    };

    useDynamicConfig = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Use a writable config file in dataDir instead of the Nix store.
        Enable if you rely on the Numa REST API to dynamically update config.
      '';
    };

    upstreamDns = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "223.5.5.5" "119.29.29.29" ];
      description = "Upstream DNS servers";
    };

    src = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "Pre-built binary source. Format: { url = ...; narHash = \"sha256-...\"; }";
      example = {
        url = "https://github.com/razvandimescu/numa/releases/latest/download/numa-linux-x86_64.tar.gz";
        narHash = "sha256-mOSJdpZlZmTc7PU50ACL2lvDtywdMrOL7g8lvSqtUx0=";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # ── Numa package (pre-built binary, auto-patchelf) ──
    nixpkgs.overlays = [
      (final: prev: {
        numa = prev.stdenv.mkDerivation {
          pname = "numa";
          version = "latest";
          src = srcPath;
          dontUnpack = true;
          nativeBuildInputs = [ prev.autoPatchelfHook ];
          buildInputs = [ prev.libgcc.lib ];
          installPhase = ''
            mkdir -p $out/bin
            tar xzf $src -C $out/bin
            chmod +x $out/bin/numa
          '';
        };
      })
    ];

    # ── Data directory ────────────────────────────────────
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 - - -"
    ];

    # ── Copy static config on first start if dynamic mode ─
    systemd.services.numa-init = lib.mkIf cfg.useDynamicConfig {
      description = "Initialize Numa config";
      before = [ "numa.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        if [ ! -f "${configFile}" ]; then
          cp ${staticConfig} "${configFile}"
          chmod 644 "${configFile}"
        fi
      '';
    };

    # ── Numa systemd service ──────────────────────────────
    systemd.services.numa = {
      description = "Numa - Local DNS resolver and reverse proxy";
      after = [ "network.target" ] ++ lib.optional cfg.useDynamicConfig "numa-init.service";
      wants = lib.optional cfg.useDynamicConfig "numa-init.service";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStartPre = lib.mkIf cfg.useDynamicConfig ''
          ${pkgs.bash}/bin/bash -c 'test -f ${configFile} || cp ${staticConfig} ${configFile}'
        '';
        ExecStart = "${pkgs.numa}/bin/numa ${
          if cfg.useDynamicConfig then configFile else staticConfig
        }";
        Restart = "on-failure";
        RestartSec = "5s";
        # Bind privileged ports: 53 (DNS), 80/443 (proxy), 853 (DoT)
        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
        DynamicUser = true;
        StateDirectory = "numa";
        ReadWritePaths = lib.mkIf cfg.useDynamicConfig [ cfg.dataDir ];
      };
    };

    # ── System DNS points to local Numa ───────────────────
    networking.nameservers = [ "127.0.0.1" ];

    # Disable NetworkManager DNS management
    networking.networkmanager.dns = "none";

    # systemd-resolved must release port 53 — disable entirely (like coredns.nix)
    services.resolved.enable = false;

    # ── Firewall ──────────────────────────────────────────
    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ 80 443 5380 853 ];
      allowedUDPPorts = [ 53 443 ];
    };
  };
}
