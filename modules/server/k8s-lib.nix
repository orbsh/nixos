# K8s 节点构建工具函数
# 集中管理角色模块映射和节点生成逻辑
{ nixpkgs, inputs, dataDir }:
let
  lib = nixpkgs.lib;

  # ── 角色模块映射 ─────────────────────────────────────────
  # combo 模式同时导入 control 和 worker 模块，roles 列表会合并为 [ "master" "worker" ]
  k8sRoleModules = {
    control = [ ./k8s-control.nix ];
    worker  = [ ./k8s-worker.nix ];
    combo   = [
      ./k8s-control.nix
      ./k8s-worker.nix
      # 显式合并角色，确保 combo 节点同时注册为 master 和 node
      { services.kubernetes.roles = [ "master" "node" ]; }
      # Combo 节点：移除 control-plane taint，允许调度普通 Pod
      # 注意：必须在 k8s-common.nix 的 baseKubeletOpts 基础上追加
      {
        services.kubernetes.kubelet.extraOpts = lib.mkForce
          "--container-runtime-endpoint=unix:///run/crio/crio.sock --runtime-request-timeout=10m --max-pods=500 --register-with-taints=\"\"";
      }
    ];
  };
in
{
  # K8s 节点生成函数
  mkK8sNode = name: attrs: let
    # 提取已处理的属性，其余作为 NixOS 模块注入
    nodeModule = lib.removeAttrs attrs [ "hostname" "ip" "role" "imports" ];
  in lib.nixosSystem {
    specialArgs = { inherit inputs dataDir; };
    modules = [
      { nixpkgs.hostPlatform = "x86_64-linux"; }
      ../../hosts/k8s-role.nix
    ] ++ k8sRoleModules.${attrs.role} ++ [
      # 注入节点特定的 Hostname 和 IP 配置
      {
        networking.hostName = attrs.hostname or name;
      }
      {
        networking.interfaces.eth0.ipv4.addresses = [{
          address = attrs.ip or (throw "k8s node '${name}' is missing required 'ip' field");
          prefixLength = 24;
        }];
        # kubernetes 必需：master 节点的地址
        services.kubernetes.masterAddress = attrs.ip;
      }
      # 注入节点的额外配置（如 fileSystems、services 等）
      nodeModule
    ] ++ attrs.imports;
  };
}
