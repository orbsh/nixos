{ pkgs, lib, user, ... }:

let
  userWallpaperDir = "/home/${user}/Pictures/wallpaper";
  targetDir = "/var/lib/greetd-wallpapers";
  targetFile = "${targetDir}/wallpaper";
in
{
  # ── Greetd + ReGreet 登录管理器 ──────────────────────────
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.cage}/bin/cage -s -- ${pkgs.regreet}/bin/regreet";
        user = "greeter";
      };
    };
  };

  # Cosmic 不依赖 GNOME keyring，关掉避免 PAM auto_start 延迟
  security.pam.services.greetd.enableGnomeKeyring = false;

  systemd.services.greetd-wallpaper-rotator = {
    description = "Randomly pick a login wallpaper before greetd starts";
    wantedBy = [ "greetd.service" ];
    before = [ "greetd.service" ];
    script = ''
      mkdir -p ${targetDir}
      RANDOM_IMG=$(${pkgs.fd}/bin/fd . ${userWallpaperDir} -d 1 -t f -e jpg -e jpeg -e png | shuf -n 1)
      if [ -n "$RANDOM_IMG" ]; then
        cp -f "$RANDOM_IMG" ${targetFile}
      else
        ${pkgs.imagemagick}/bin/magick convert -size 1920x1080 xc:"#1e1e28" ${targetFile}
      fi
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  programs.regreet = {
    enable = true;
    settings = {
      skip_selection = false;
      background = {
        path = targetFile;
        fit = "Cover";
      };
      commands = {
        reboot = [ "systemctl" "reboot" ];
        poweroff = [ "systemctl" "poweroff" ];
        x11_prefix = [ "startx" "/usr/bin/env" ];
      };
      GTK = {
        application_prefer_dark_theme = true;
      };
      appearance = {
        greeting_msg = "Welcome back!";
      };
    };
    extraCss = ''
      box {
        justify-content: center;
        align-items: center;
      }
      window #container {
        background: transparent;
        border: none;
        box-shadow: none;
      }
      entry {
        background-color: rgba(255, 255, 255, 0.05);
        backdrop-filter: blur(2px);
        border-radius: 16px;
        border: 1px solid rgba(255, 255, 255, 0.08);
        color: rgba(255, 255, 255, 0.3);
        padding: 14px 22px;
        transition: all 300ms ease-in-out;
      }
      entry:focus {
        background-color: rgba(255, 255, 255, 0.15);
        backdrop-filter: blur(15px);
        border: 1px solid rgba(255, 255, 255, 0.6);
        color: #ffffff;
        box-shadow: 0 0 20px rgba(255, 255, 255, 0.25);
      }
    '';
  };

  systemd.tmpfiles.rules = [
    "d ${targetDir} 0755 root root -"
  ];
}
