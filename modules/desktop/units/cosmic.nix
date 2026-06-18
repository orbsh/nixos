{ pkgs, lib, dataDir, user, ... }: {
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
      "pop-launcher/plugins/cwdhist/main.py" = {
        source = ../assets/pop-launcher/cwdhist/main.py;
        executable = true;
      };
      "pop-launcher/plugins/cwdhist/plugin.ron".source = ../assets/pop-launcher/cwdhist/plugin.ron;
      "pop-launcher/plugins/zellij/main.py" = {
        source = ../assets/pop-launcher/zellij/main.py;
        executable = true;
      };
      "pop-launcher/plugins/zellij/plugin.ron".source = ../assets/pop-launcher/zellij/plugin.ron;
    };
  };
}
