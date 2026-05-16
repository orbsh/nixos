# K8s 节点构建工具函数
# 集中管理角色模块映射和节点生成逻辑
{ nixpkgs, inputs, dataDir }:
let
  lib = nixpkgs.lib;

  # ── 角色模块映射 ─────────────────────────────────────────
  # combo 模式同时导入 control 和 worker 模块，roles 列表会合并为 [ "master" "worker" ]
  # 注意：combo 的 socket 路径配置由 mkK8sNode 函数动态生成，不在此处硬编码
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
      # socket 路径由 mkK8sNode 根据 runtime 动态注入
    ];
  };

  # 容器运行时 socket 路径映射
  runtimeSocketPaths = {
    crio = "/run/crio/crio.sock";
    containerd = "/run/containerd/containerd.sock";
  };

  # 容器运行时模块映射（在此处导入，避免 k8s-common.nix 中引用 config 导致无限递归）
  runtimeModules = {
    crio = ./crio.nix;
    containerd = ./containerd.nix;
  };
in
{
  # K8s 节点生成函数
  mkK8sNode = name: attrs: let
    # 提取已处理的属性，其余作为 NixOS 模块注入
    nodeModule = lib.removeAttrs attrs [ "hostname" "ip" "role" "runtime" "imports" ];
    # 获取运行时（必须显式指定）
    runtime = attrs.runtime or (throw "k8s node '${name}' is missing required 'runtime' field");
    # 获取 socket 路径
    socketPath = runtimeSocketPaths.${runtime} or (throw "k8s node '${name}' has unsupported runtime '${runtime}'");
    # combo 角色需要额外注入 socket 路径配置
    comboSocketModule = if attrs.role == "combo" then [{
      services.kubernetes.kubelet.extraOpts = lib.mkForce ''
        --container-runtime-endpoint=unix://${socketPath} --runtime-request-timeout=10m --max-pods=500 --register-with-taints=""
      '';
    }] else [];
  in lib.nixosSystem {
    specialArgs = { inherit inputs dataDir; };
    modules = [
      { nixpkgs.hostPlatform = "x86_64-linux"; }
      ../../hosts/k8s-role.nix
    ] ++ k8sRoleModules.${attrs.role} ++ comboSocketModule ++ [
      # 导入运行时特定模块
      runtimeModules.${runtime}
      # 注入节点特定的配置
      {
        networking.hostName = attrs.hostname or name;
        # 容器运行时选择（必须显式指定）
        services.kubernetes.runtime = runtime;
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
