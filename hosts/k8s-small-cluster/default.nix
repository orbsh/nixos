# 小集群示例（控制+工作合一，适合 1-3 台节点省资源）
#
# 角色：同时运行控制平面组件和 kubelet，允许调度普通 Pod
# 注意：combo 节点默认有 control-plane taint，k8s-libs.nix 会自动移除
{ user, ... }:
{
  # ── 集群级配置 ────────────────────────────────────────
  runtime = "containerd";  # 容器运行时：crio / containerd
  podCIDR = "10.1.0.0/16";  # 集群 Pod CIDR（需包含各节点 PodCIDR，如 10.1.1.0/24）
  adminEmail = "admin@example.com";  # 集群管理员邮箱

  # ── 节点定义 ──────────────────────────────────────────
  nodes = {
    combo-01 = {
      hostname = "combo-01";
      ip = "192.168.1.31";
      role = "combo";
      imports = [
        ./disk.nix
      ];
      fileSystems."/home/${user}/data" = {
        device = "/dev/vdb";
        fsType = "ext4";
        options = [ "nofail" ];
      };
    };
    worker-02 = {
      hostname = "worker-02";
      ip = "192.168.1.32";
      role = "worker";
      imports = [
        ./disk.nix
      ];
      fileSystems."/home/${user}/data" = {
        device = "/dev/vdb";
        fsType = "ext4";
        options = [ "nofail" ];
      };
    };
    worker-03 = {
      hostname = "worker-03";
      ip = "192.168.1.33";
      role = "worker";
      imports = [
        ./disk.nix
      ];
      fileSystems."/home/${user}/data" = {
        device = "/dev/vdb";
        fsType = "ext4";
        options = [ "nofail" ];
      };
    };
  };
}
