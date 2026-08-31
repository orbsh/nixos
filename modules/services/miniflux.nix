# miniflux 服务单元（自包含：app-net 共享网络 + miniflux pod）
# 引用 podman/ 内多个基础设施，与 ladder 同层同构。
{ config, lib, ... }:
{
  imports = [
    ./podman/network.nix
    ./podman/miniflux.nix
  ];

  options.services.miniflux = {
    port = lib.mkOption {
      type = lib.types.int;
      default = 8090;
      description = "miniflux Web 界面 host 端口（映射到容器 8080）";
    };
  };
}