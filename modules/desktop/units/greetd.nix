{ pkgs, lib, user, ... }:

let
  userWallpaperDir = "/home/${user}/Pictures/wallpaper";
  targetDir = "/var/lib/greetd-wallpapers";
  targetFile = "${targetDir}/wallpaper.jpg";
in
{
  # 1. 启用 COSMIC Greeter
  services.displayManager.cosmic-greeter.enable = true;

  # 2. 禁用 Keyring
  services.gnome.gnome-keyring.enable = false;

  # 3. 壁纸服务
  systemd.services.cosmic-greeter-wallpaper-rotator = {
    description = "Randomly pick a login wallpaper";
    wantedBy = [ "cosmic-greeter.service" ];
    before = [ "cosmic-greeter.service" ];
    script = ''
      mkdir -p ${targetDir}
      img=$(${pkgs.fd}/bin/fd . ${userWallpaperDir} -d 1 -t f -e jpg -e jpeg -e png | shuf -n 1)
      if [ -n "$img" ]; then
        ${pkgs.imagemagick}/bin/magick convert "$img" -resize "1920x1080^" -gravity center -extent 1920x1080 jpg:${targetFile}
      else
        ${pkgs.imagemagick}/bin/magick convert -size 1920x1080 xc:"#1e1e28" ${targetFile}
      fi
      chmod 644 ${targetFile}
    '';
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
  };

  systemd.tmpfiles.rules = [ "d ${targetDir} 0755 root root -" ];
}
