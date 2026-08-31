# gitea 服务单元（自包含：app-net 共享网络 + gitea pod）
# 引用 podman/ 内多个基础设施，与 ladder 同层同构；network.nix 幂等，多服务共享 app-net。
{ config, lib, ... }:
{
  # imports 必须在模块顶层（不能进 config）
  imports = [
    ./podman/network.nix
    ./podman/gitea.nix
  ];

  options.services.gitea = {
    port = lib.mkOption {
      type = lib.types.int;
      default = 3333;
      description = "gitea Web 界面 host 端口（映射到容器 3000）";
    };
    sshPort = lib.mkOption {
      type = lib.types.int;
      default = 3322;
      description = "gitea SSH host 端口（映射到容器 22）";
    };
  };
}