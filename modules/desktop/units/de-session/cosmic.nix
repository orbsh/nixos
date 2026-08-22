{ pkgs, lib, dataDir, user, config, ... }:

let
  # ── COSMIC Git overlay 开关 ─────────────────────────
  # true: 通过 nixos-cosmic 叠加 Git 版 COSMIC（覆盖 nixpkgs 内置版本）
  # false: 使用 nixpkgs 内置版本
  useGitOverlay = false;

  nixosCosmicSrc = builtins.fetchGit {
    url = "https://github.com/lilyinstarlight/nixos-cosmic";
    shallow = true;
  };

  gitOverlay = import (nixosCosmicSrc + "/module.nix");

  # 上游 hash 修正（GitHub 重新生成 tarball 导致 hash 过期）
  cosmicHashFix = final: prev: {
    cosmic-edit = prev.cosmic-edit.overrideAttrs (_: {
      src = final.fetchFromGitHub {
        owner = "pop-os";
        repo = "cosmic-edit";
        rev = "020342119d0ac4d362f7642a97eecade3d766177";
        hash = "sha256-GN1Zts+v3ARcrkN+ZkMUSGNOAlIhXSYWRtWAyqUfUrY=";
      };
    });
    cosmic-greeter = prev.cosmic-greeter.overrideAttrs (_: {
      src = final.fetchFromGitHub {
        owner = "pop-os";
        repo = "cosmic-greeter";
        rev = "2d2543094e04ae3167f71a5986626f03663beb79";
        hash = "sha256-ERytoauws6FDJNXItflOE2MwjxwariiO8RXU1x1chkE=";
      };
    });
  };

  # Generate plugin.ron from Python class
  genPluginRon = { pluginPath, className }:
    let
      genScript = pkgs.writeText "gen_plugin_ron.py" ''
        import sys
        sys.path.insert(0, '.')
        import main
        plugin_class = getattr(main, '@className@')
        print(plugin_class().plugin_ron, end="")
      '';
      genScriptSubstituted = pkgs.substitute {
        src = genScript;
        substitutions = [ "--subst-var-by" "className" className ];
      };
    in
    pkgs.runCommand "${className}-plugin.ron" {
      nativeBuildInputs = [ pkgs.python3 ];
    } ''
      mkdir -p build
      cp ${../../assets/pop-launcher/framework.py} build/framework.py
      cp ${pluginPath} build/main.py
      cd build
      python3 ${genScriptSubstituted} > $out
    '';
in
{
  # ── COSMIC Git overlay（不随 enable 变化） ──────────────
  imports = lib.optional useGitOverlay gitOverlay;
  nixpkgs.overlays = lib.optional useGitOverlay cosmicHashFix;

  # 活跃谓词（供 de-session dispatcher 使用）
  desktop.sessions.cosmic.predicate = "${pkgs.procps}/bin/pgrep -f cosmic-comp";

  # ── COSMIC Desktop Environment ─────────────────────────
  services.desktopManager.cosmic.enable = true;

  # ── Pipewire Audio ─────────────────────────────────────
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # ── XDG Desktop Portal (COSMIC backend) ────────────────
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-cosmic ];
  };

  # ── Pop Launcher Plugins (HM) ──────────────────────────
  home-manager.users.${user} = {
    xdg.dataFile = {
      "pop-launcher/framework.py" = {
        source = ../../assets/pop-launcher/framework.py;
        force = true;
      };
      "pop-launcher/plugins/cwdhist/main.py" = {
        source = ../../assets/pop-launcher/cwdhist/main.py;
        executable = true;
      };
      "pop-launcher/plugins/cwdhist/plugin.ron".source = genPluginRon {
        pluginPath = ../../assets/pop-launcher/cwdhist/main.py;
        className = "CwdHistPlugin";
      };
      "pop-launcher/plugins/zellij/main.py" = {
        source = ../../assets/pop-launcher/zellij/main.py;
        executable = true;
      };
      "pop-launcher/plugins/zellij/plugin.ron".source = genPluginRon {
        pluginPath = ../../assets/pop-launcher/zellij/main.py;
        className = "ZellijPlugin";
      };
    };
  };
}