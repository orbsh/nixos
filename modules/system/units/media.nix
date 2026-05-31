{ pkgs, ... }: {
  # ── 媒体处理工具 ─────────────────────────────────────────
  # ImageMagick：图片格式转换、缩放、合成
  # FFmpeg：视频/音频转码、截取、流处理
  environment.systemPackages = with pkgs; [
    imagemagick
    ffmpeg
  ];
}
