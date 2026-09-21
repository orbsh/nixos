# 连自建 netbird-server（部署在阿里云 K8s tunnel 命名空间）
# 注册方式：setup key 手动登录 `netbird-wt0 up --setup-key <key>`
{ ... }:
{
  imports = [ ../../../modules/services/netbird.nix ];

  services.myNetbird = {
    enable = true;
    managementUrl = "https://netbird.xinminghui.com";
    # DNS 独立于系统解析（numa 按 *.n suffix 转发给 netbird resolver），
    # 不吃整条 resolv.conf——与 tailscale 的 acceptDns=false 同一取舍
  };
}
