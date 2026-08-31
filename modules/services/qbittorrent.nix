# qbittorrent 服务单元（自包含：app-net 共享网络 + qbittorrent pod）
# 引用 podman/ 内多个基础设施，与 ladder 同层同构。
{ config, lib, ... }:
{
  imports = [
    ./podman/network.nix
    ./podman/qbittorrent.nix
  ];

  options.services.qbittorrent = {
    port = lib.mkOption {
      type = lib.types.int;
      default = 8181;
      description = "qbittorrent Web UI host 端口（映射到容器 8080）";
    };
    torrentPort = lib.mkOption {
      type = lib.types.int;
      default = 6881;
      description = "qbittorrent 下载端口（TCP/UDP）";
    };
  };
}