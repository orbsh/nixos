# dxserver 连自建 headscale（与 orbit 同一控制面）
# 注册方式：preauthkey（服务端生成，tailscale up 时 --authkey 传入）
{ ... }:
{
  imports = [ ../../modules/services/tailscale.nix ];

  services.myTailscale = {
    enable = true;
    loginServer = "https://headscale.xinminghui.com";
    # 服务器无桌面环境，MagicDNS 可用；但与 orbit 保持一致：DNS 由本机/numa 管理，
    # 避免 tailscaled 异常时拖垮整个 resolv.conf
    acceptDns = false;
  };
}
