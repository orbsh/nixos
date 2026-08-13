{ pkgs, ... }:
{
  # Blender：官方包，不带插件管理。
  # 插件/扩展（MPFB2、Molecular+、BlenderKit 等）由 fabricario 容器管线在容器内负责，
  # 工作站桌面只装一个干净的官方 blender，需要时用 BLENDER_SYSTEM_* 手动注入。
  environment.systemPackages = with pkgs; [
    blender
  ];
}