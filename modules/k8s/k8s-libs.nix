# K8s 节点构建工具函数
# 职责：接收集群数据 -> 返回扁平化的节点 Attrset
{ nixpkgs, inputs, commonArgs }:

let
  lib = nixpkgs.lib;
  inherit (commonArgs) dataDir user email;

  # ── 角色模块映射 ─────────────────────────────────────────
  k8sRoleModules = {
    control = [ ./k8s-control.nix ];
    worker  = [ ./k8s-worker.nix ];
    combo   = [
      ./k8s-control.nix
      ./k8s-worker.nix
      { services.kubernetes.roles = [ "master" "node" ]; }
    ];
  };

  # ── 计算 cni0 桥接 IP ─────────────────────────────
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

  runtimeModules = {
    crio = ./crio.nix;
    containerd = ./containerd.nix;
  };

  # ── 展平 clusters 结构 ───────────────────────────────
  # 输入：domainName, clusterDef (runtime, podCIDR, nodes...)
  # 输出：{ "domain__node" = { ... }; ... }
  expandCluster = domainName: clusterDef:
    let
      runtime = clusterDef.runtime;
      podCIDR = clusterDef.podCIDR;
      adminEmail = clusterDef.adminEmail or null;
      cni0 = cni0IP podCIDR;

      # 获取 Master IP (第一个 control/combo 节点)
      controlNodes = builtins.filter (n:
        let role = clusterDef.nodes.${n}.role; in role == "control" || role == "combo"
      ) (builtins.attrNames clusterDef.nodes);

      masterIP = if controlNodes != [] then clusterDef.nodes.${builtins.head controlNodes}.ip else null;

      # 辅助函数：为每个节点注入 K8s 上下文
      buildNode = nodeName: nodeAttrs: {
        inherit nodeName domainName;

        # K8s 专属属性，供构建器识别
        isK8sNode = true;
        k8sRole = nodeAttrs.role;
        runtime = runtime;
        podCIDR = podCIDR;
        masterIP = if masterIP != null then masterIP else nodeAttrs.ip;
        cni0IP = cni0;

        # 节点特定属性
        ip = nodeAttrs.ip or (throw "k8s node '${nodeName}' missing 'ip'");
        hostname = nodeAttrs.hostname;

        # 动态模块列表
        imports =
          [ ../../modules/presets/server.nix ] ++
          k8sRoleModules.${nodeAttrs.role} ++
          (clusterDef.clusterModules or []) ++
          [
            runtimeModules.${runtime}
            {
              services.kubernetes = {
                runtime = runtime;
                podCIDR = podCIDR;
                masterAddress = if masterIP != null then masterIP else nodeAttrs.ip;
                adminEmail = lib.mkIf (adminEmail != null) adminEmail;
                # 自动为第一个 control 节点添加 SANs
                apiserver.extraSANs = if nodeName == builtins.head controlNodes then [ nodeAttrs.ip ] else [];
                # 证书同步
                isCertServer = nodeName == builtins.head controlNodes;
                autoSyncCerts = nodeName != builtins.head controlNodes;
              };
            }
          ] ++ (
            if nodeAttrs.role == "combo" then [{
              services.kubernetes.kubelet.extraOpts = lib.mkForce ''
                --container-runtime-endpoint=unix://${runtimeSocketPaths.${runtime}} --runtime-request-timeout=10m --max-pods=500 --register-with-taints=""
              '';
            }] else []
          ) ++ (nodeAttrs.imports or []);
      } // lib.removeAttrs nodeAttrs [ "hostname" "ip" "role" "imports" ];

    in
    builtins.mapAttrs buildNode clusterDef.nodes;

in
{ inherit cni0IP expandCluster; }
