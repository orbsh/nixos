# 连自建 netbird-server（部署在阿里云 K8s tunnel 命名空间）
# 注册方式：setup key 手动登录 `netbird-wt0 up --setup-key <key>`
{ config, lib, ... }:
{
  imports = [ ../../../modules/services/netbird.nix ];

  services.myNetbird = {
    enable = true;
    managementUrl = "https://netbird.xinminghui.com";
    # DNS 独立于系统解析（不吃整条 resolv.conf，disableDns 默认 true），
    # 客户端内建 resolver 地址由下面 numa forwarding 按 *.n.b 转发进来——
    # 与 tailscale 的 acceptDns=false 同一取舍。
  };

  # MagicDNS：*.n.b → netbird 客户端 resolver。netbird 拒绝单标签 DNS domain
  # （dashboard 校验 domainPattern 需两段以上），故服务端账号 domain 设 n.b，
  # numa 转发 suffix 与之保持一致。
  services.numa.forwarding = lib.mkAfter [
    { suffix = "n.b"; upstream = config.services.myNetbird.dnsResolverAddress; }
  ];
}