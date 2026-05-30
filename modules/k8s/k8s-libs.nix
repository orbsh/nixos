# K8s 节点构建工具函数
# 集中管理角色模块映射和节点生成逻辑
{ nixpkgs, inputs, dataDir, user, email }:
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

  # ── 计算 cni0 桥接 IP ─────────────────────────────
  # Flannel 默认 SubnetLen=24，保留第一个 /24，第一个节点用第二个 /24
  # 算法：network_base + 257（跳过第一个 /24 的 256 地址 + 第一个可用 IP）
  # 10.1.0.0/16 → 10.1.1.1 | 10.0.0.0/12 → 10.0.1.1 | 192.168.0.0/16 → 192.168.1.1
  cni0IP = cidr: let
    cidrBase = lib.head (lib.splitString "/" cidr);
    octets = lib.map (lib.toInt) (lib.splitString "." cidrBase);
    ipInt = (lib.elemAt octets 0) * 16777216
          + (lib.elemAt octets 1) * 65536
          + (lib.elemAt octets 2) * 256
          + (lib.elemAt octets 3)
          + 257;
    o1 = builtins.floor (ipInt / 16777216);
    o2 = builtins.floor ((ipInt - o1 * 16777216) / 65536);
    o3 = builtins.floor ((ipInt - o1 * 16777216 - o2 * 65536) / 256);
    o4 = ipInt - o1 * 16777216 - o2 * 65536 - o3 * 256;
  in "${toString o1}.${toString o2}.${toString o3}.${toString o4}";

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

  # ── 展平 clusters 结构，自动注入 runtime 和 masterIP ──
  # 输入：{ clusterName = { runtime; nodes; }; }
  # 输出：{ "cluster__node" = { runtime; masterIP?; ... }; }
  flattenClusters = clusters:
    builtins.foldl' (acc: clusterName:
      let
        cluster = clusters.${clusterName};
        # 包含 control 和 combo 角色
        controlNodes = builtins.filter (n:
          let role = cluster.nodes.${n}.role;
          in role == "control" || role == "combo"
        ) (builtins.attrNames cluster.nodes);
        masterIP = if controlNodes != [] then cluster.nodes.${builtins.head controlNodes}.ip else null;
        injectMasterIP = nodeName: nodeAttrs:
          let isFirst = controlNodes != [] && nodeName == builtins.head controlNodes;
          in if nodeAttrs.role == "worker" || (!isFirst && (nodeAttrs.role == "control" || nodeAttrs.role == "combo"))
            then nodeAttrs // { inherit masterIP; isFirstControl = false; }
            else nodeAttrs // { isFirstControl = isFirst; };
      in
      acc // (builtins.foldl' (nodeAcc: nodeName:
        nodeAcc // {
          "${clusterName}__${nodeName}" = (injectMasterIP nodeName cluster.nodes.${nodeName}) // { runtime = cluster.runtime; } // (lib.optionalAttrs (cluster ? adminEmail) { inherit (cluster) adminEmail; }) // (lib.optionalAttrs (cluster ? podCIDR) { inherit (cluster) podCIDR; });
        }
      ) {} (builtins.attrNames cluster.nodes))
    ) {} (builtins.attrNames clusters);

  # ── K8s 节点生成函数 ─────────────────────────────────
  mkK8sNode = name: attrs: let
    # 提取已处理的属性，其余作为 NixOS 模块注入
    nodeModule = lib.removeAttrs attrs [ "hostname" "ip" "role" "runtime" "imports" "masterIP" "isFirstControl" "adminEmail" "podCIDR" ];
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
    # 自动为第一个 control/combo 节点添加 API Server SANs
    autoSansModule = lib.optionalAttrs (attrs.isFirstControl or false) {
      services.kubernetes.apiserver.extraSANs = [ attrs.ip ];
    };
    # 证书同步：首个 control 节点提供服务，其他节点启用同步
    certSyncModule = if attrs.isFirstControl or false then [
      # Master 节点：启动 socat 证书服务
      {
        services.kubernetes.isCertServer = true;
      }
    ] else [
      # Worker/Secondary 节点：启用 nc 同步
      {
        services.kubernetes.autoSyncCerts = true;
      }
    ];
  in lib.nixosSystem {
    specialArgs = { inherit inputs dataDir user email cni0IP; };
    modules = [
      { nixpkgs.hostPlatform = "x86_64-linux"; }
      ../../hosts/k8s-role.nix
    ] ++ k8sRoleModules.${attrs.role} ++ comboSocketModule ++ [
      # 自动为第一个 control/combo 节点添加 API Server SANs
      autoSansModule
    ] ++ certSyncModule ++ [
      # 导入运行时特定模块
      runtimeModules.${runtime}
      # 注入节点特定的配置
      {
        networking.hostName = attrs.hostname or name;
        # 容器运行时选择（必须显式指定）
        services.kubernetes.runtime = runtime;
        # 集群管理员邮箱（可选）
        services.kubernetes.adminEmail = attrs.adminEmail or null;
        # 集群 Pod CIDR（必须指定）
        services.kubernetes.podCIDR = attrs.podCIDR or (throw "k8s node '${name}' is missing required 'podCIDR' field");
      }
      {
        networking.interfaces.eth0.ipv4.addresses = [{
          address = attrs.ip or (throw "k8s node '${name}' is missing required 'ip' field");
          prefixLength = 24;
        }];
        # kubernetes 必需：控制平面地址（worker 节点通过 masterIP 指向 master，master 节点指向自己）
        services.kubernetes.masterAddress = attrs.masterIP or attrs.ip;
      }
      # 注入节点的额外配置（如 fileSystems、services 等）
      nodeModule
    ] ++ attrs.imports;
  };

  # ── 导出库 ───────────────────────────────────────────
  k8sLib = { inherit cni0IP flattenClusters mkK8sNode; };
in
k8sLib
