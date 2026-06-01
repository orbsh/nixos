# K8s 开发集群
{ inputs, user, lib, dataDir, ... }:

let
  runtime = "containerd";
in {
  inherit runtime;
  podCIDR = "10.1.0.0/16";
  adminEmail = "nash@iffy.me";

  # 集群级模块（自动注入到所有节点）
  clusterModules = [
    (import ../../libs/registries-gen.nix {
      inherit lib runtime;
      registriesData = import ./registries.nix;
    })
  ];

  nodes = {
    dxserver = {
      hostname = "dxserver";
      ip = "172.178.5.123";
      useDHCP = true;
      role = "combo";
      imports = [
        # 引用 dxserver 的物理硬件画像
        ../server/hardware/disk.nix
        ../server/hardware/hardware-configuration.nix
        ../server/hardware/wireguard.nix
        # K8s 插件
        ../../modules/k8s/coredns.nix
      ];

      # CoreDNS 内网 DNS 服务
      services.myCoredns = {
        templates = [
          { zone = "s"; answers = [ "172.178.5.123" ]; }
          { zone = "a"; answers = [ "172.178.1.37" ]; }
          { zone = "x"; answers = [ "172.178.1.58" "172.178.1.37" ]; }
        ];
        forward = {
          upstream = [ "223.5.5.5" "119.29.29.29" "1.1.1.1" ];
          forceTcp = false;
        };
      };

      # 数据盘挂载
      fileSystems."/home/${user}/data" = {
        device = "/dev/disk/by-uuid/79967e21-e2d6-4fc4-a8a4-e45dedf211ef";
        fsType = "btrfs";
        options = [ "compress=zstd" "subvol=@" "nofail" ];
      };

      # 允许特定密钥免密登录（格式：ssh-ed25519/ssh-rsa + 公钥 + 注释）
      users.users.${user}.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAzNo0nUZQcEZBIubufcp0cC2x56Giul8iif1iWDRySb ${user}@dx"
      ];

      # ── 节点特有 API Server SANs ─────────────────────────
      # 已由 k8s-libs.nix 自动为第一个 control/combo 节点注入
      # 如需额外 SAN，可在此追加：
      services.kubernetes.apiserver.extraSANs = [ "10.6.6.2" ];
    };
  };
}
