# dxserver 连自建 netbird-server（与 orbit 同一控制面）
# 注册方式：setup key 手动登录 `netbird-wt0 up --setup-key <key>`
{ ... }:
{
  imports = [ ../../modules/services/netbird.nix ];

  services.myNetbird = {
    enable = true;
    managementUrl = "https://netbird.xinminghui.com";
    # 服务器无 numa（也不吃 netbird 下发的系统 DNS，disableDns 默认 true），
    # 与 orbit 同一取舍；MagicDNS 不进本机解析。
  };
}