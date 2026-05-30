{ config, pkgs, ... }:
{
  # 禁用 xdg-user-dirs-update 自动更新，防止根据 locale 创建中文目录
  xdg.configFile."user-dirs.conf".text = ''
    enabled=False
  '';
  xdg = {
    enable = true;

    userDirs = {
      enable        = true;
      createDirectories = true;
      documents  = "${config.home.homeDirectory}/doc";
      download   = "${config.home.homeDirectory}/dl";
      pictures   = "${config.home.homeDirectory}/pic";
      videos     = "${config.home.homeDirectory}/vid";
      music      = "${config.home.homeDirectory}/music";
      # 不需要的目录设为 home，避免自动创建
      desktop    = "${config.home.homeDirectory}";
      templates  = "${config.home.homeDirectory}";
      publicShare = "${config.home.homeDirectory}";
    };

    mimeApps = {
      enable = true;
      defaultApplications = {
        "application/pdf"       = "org.pwmt.zathura.desktop";
        "image/png"             = "krita.desktop";
        "image/jpeg"            = "krita.desktop";
        "image/svg+xml"         = "krita.desktop";
        "video/mp4"             = "smplayer.desktop";
        "video/mkv"             = "smplayer.desktop";
        "text/html"             = "vivaldi-stable.desktop";
        "x-scheme-handler/http" = "vivaldi-stable.desktop";
        "x-scheme-handler/https"= "vivaldi-stable.desktop";
        "application/epub+zip"  = "com.calibre_ebook.calibre.desktop";
        "text/plain"            = "dev.zed.Zed.desktop";
      };
    };
  };

  # 环境变量（用户级）
  home.sessionVariables = {
    EDITOR      = "hx";
    VISUAL      = "hx";
    BROWSER     = "vivaldi";
    PAGER       = "glow";
    # podman socket（让某些工具以为在用 docker）
    DOCKER_HOST = "unix:///run/user/1000/podman/podman.sock";
    # Rust
    CARGO_HOME  = "${config.home.homeDirectory}/.cargo";
    RUSTUP_HOME = "${config.home.homeDirectory}/.rustup";
  };
}
