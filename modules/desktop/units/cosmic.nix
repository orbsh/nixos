{ pkgs, lib, dataDir, user, ... }:

let
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
      cp ${../assets/pop-launcher/framework.py} build/framework.py
      cp ${pluginPath} build/main.py
      cd build
      python3 ${genScriptSubstituted} > $out
    '';
in
{
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
        source = ../assets/pop-launcher/framework.py;
        force = true;
      };
      "pop-launcher/plugins/cwdhist/main.py" = {
        source = ../assets/pop-launcher/cwdhist/main.py;
        executable = true;
      };
      "pop-launcher/plugins/cwdhist/plugin.ron".source = genPluginRon {
        pluginPath = ../assets/pop-launcher/cwdhist/main.py;
        className = "CwdHistPlugin";
      };
      "pop-launcher/plugins/zellij/main.py" = {
        source = ../assets/pop-launcher/zellij/main.py;
        executable = true;
      };
      "pop-launcher/plugins/zellij/plugin.ron".source = genPluginRon {
        pluginPath = ../assets/pop-launcher/zellij/main.py;
        className = "ZellijPlugin";
      };
    };
  };
}
