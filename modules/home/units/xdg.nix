{ config, pkgs, ... }:

# 定义默认应用程序变量
let
  # 媒体播放器
  mediaPlayer = "mpv.desktop";

  # 归档管理器
  archiver = "io.github.peazip.PeaZip.desktop";

  # 图像查看器
  imageViewers = "org.nomacs.ImageLounge.desktop";

  # 文本编辑器
  textEditor = "dev.zed.Zed.desktop";

  # 浏览器
  browser = "vivaldi-stable.desktop";

  # 电子书阅读器
  ebookReader = "com.github.johnfactotum.Foliate.desktop";

  # PDF 阅读器
  pdfReader = "com.github.johnfactotum.Foliate.desktop";

  # 办公软件
  libreOfficeWriter = "libreoffice-writer.desktop";
  libreOfficeCalc = "libreoffice-calc.desktop";
  libreOfficeImpress = "libreoffice-impress.desktop";
in
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
      documents  = "${config.home.homeDirectory}/Documents";
      download   = "${config.home.homeDirectory}/Downloads";
      pictures   = "${config.home.homeDirectory}/Pictures";
      videos     = "${config.home.homeDirectory}/Videos";
      music      = "${config.home.homeDirectory}/Music";
      desktop    = "${config.home.homeDirectory}/Desktop";
      templates  = "${config.home.homeDirectory}/Templates";
      publicShare = "${config.home.homeDirectory}/pub";
    };

    mimeApps = {
      enable = true;
      defaultApplications = {
        # PDF 文档
        "application/pdf"       = pdfReader;

        # 图像文件
        "image/png"             = imageViewers;
        "image/jpeg"            = imageViewers;
        "image/gif"             = imageViewers;
        "image/svg+xml"         = imageViewers;
        "image/webp"            = imageViewers;

        # 视频文件
        "video/mp4"             = mediaPlayer;
        "video/mkv"             = mediaPlayer;
        "video/avi"             = mediaPlayer;
        "video/x-msvideo"       = mediaPlayer;
        "video/mpeg"            = mediaPlayer;
        "video/quicktime"       = mediaPlayer;
        "video/x-ms-wmv"        = mediaPlayer;
        "video/x-flv"           = mediaPlayer;
        "video/x-matroska"      = mediaPlayer;
        "video/webm"            = mediaPlayer;

        # 音频文件
        "audio/mp3"             = mediaPlayer;
        "audio/wav"             = mediaPlayer;
        "audio/flac"            = mediaPlayer;
        "audio/ogg"             = mediaPlayer;
        "audio/mpeg"            = mediaPlayer;
        "audio/x-m4a"           = mediaPlayer;

        # 文档和网页
        "text/html"             = browser;
        "text/plain"            = textEditor;
        "text/markdown"         = textEditor;
        "application/epub+zip"  = ebookReader;
        "application/vnd.oasis.opendocument.text" = libreOfficeWriter;
        "application/vnd.oasis.opendocument.spreadsheet" = libreOfficeCalc;
        "application/vnd.oasis.opendocument.presentation" = libreOfficeImpress;
        "application/msword" = libreOfficeWriter;
        "application/vnd.ms-excel" = libreOfficeCalc;
        "application/vnd.ms-powerpoint" = libreOfficeImpress;

        # 网址协议
        "x-scheme-handler/http" = browser;
        "x-scheme-handler/https"= browser;
        "x-scheme-handler/mailto" = browser;

        # 归档文件
        "application/zip"       = archiver;
        "application/x-tar"     = archiver;
        "application/x-rar"     = archiver;
        "application/x-7z-compressed" = archiver;
        "application/x-xz"      = archiver;
        "application/x-bzip2"   = archiver;
        "application/x-gzip"    = archiver;
        "application/x-lzma"    = archiver;
        "application/x-lz4"     = archiver;
        "application/x-lzo"     = archiver;
        "application/x-zstd"    = archiver;
        "application/rar"       = archiver;
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
