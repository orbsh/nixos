# 内网服务器域：*.s → dxserver CoreDNS（路由器曾下发该 DNS，resolv.conf 改指本机 numa 后由此分流兜住）
{ lib, ... }:
{
  services.numa.forwarding = lib.mkAfter [
    { suffix = "s"; upstream = "172.178.5.123"; }
  ];
}
