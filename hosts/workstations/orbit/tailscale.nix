# 连自建 headscale（公网域名，headscale 部署在阿里云 K8s tunnel 命名空间）
# 注册方式：preauthkey（headscale 服务端生成，tailscale up 时 --authkey 传入）
{ ... }:
{
  imports = [ ../../../modules/services/tailscale.nix ];

  services.myTailscale = {
    enable = true;
    loginServer = "https://headscale.xinminghui.com";
    # 桌面机 DNS 走 numa（本机 .d 域），不吃 MagicDNS——
    # accept-dns 会把 resolv.conf 整个切到 100.100.100.100，
    # MagicDNS 不可达时（DERP 断连）连本机服务域名都解析不了。
    acceptDns = false;
  };
}
