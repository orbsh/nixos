# 本地 Harmonia 二进制缓存客户端配置
# 用于加速 Nix 构建，优先从本地缓存获取已构建的包
{ ... }:

{
  nix.settings = {
    substituters = [
      "http://172.178.5.123:5100"
    ];
  };
}
