# Ansible → NixOS 迁移备忘

## 迁移时间

2025-05-18

## 原方案

- **配置管理**: Ansible playbook (`deployment/ansible/playbook`)
- **应用部署**: Helm charts (`deployment/helm-app`, `deployment/values`)
- **数据目录**: `deployment/data`
- **CI/CD**: 基于 Ansible 的部署流程

## 迁移必要性

### Ansible 方案的痛点

1. **不可重现** — Ansible 是命令式的，同一 playbook 在不同时间/环境执行可能产生不同结果
2. **状态不透明** — 系统实际状态取决于 playbook 执行历史和顺序，无法从配置直接推断
3. **回滚困难** — 没有内置的版本回滚机制，出错时需要手动还原
4. **依赖管理松散** — 系统包版本随时间漂移，不同节点可能安装不同版本
5. **证书管理手动** — TLS 证书需要手动生成、分发、续期，容易遗漏
6. **测试成本高** — 验证配置正确性需要实际执行 playbook，无法在构建阶段发现问题

## NixOS 优势

### 核心特性

| 特性 | Ansible | NixOS |
|------|---------|-------|
| 配置范式 | 命令式（步骤） | 声明式（状态） |
| 可重现性 | ❌ 依赖执行历史 | ✅ 同一配置永远产生相同结果 |
| 回滚 | 手动 | 一键回滚（GRUB 菜单选择上一代） |
| 原子升级 | ❌ | ✅ switch-to-configuration |
| 依赖隔离 | ❌ 全局安装 | ✅ /nix/store 隔离 |
| 构建时验证 | ❌ | ✅ nix build 阶段检查语法和依赖 |
| 证书管理 | 手动脚本 | easyCerts 自动生成 |

### 对 K8s 集群的具体收益

1. **节点配置一致性** — 所有节点使用同一份 Nix 配置，避免配置漂移
2. **kube-proxy / kubelet 等组件由模块自动管理** — 不再需要手写 systemd unit 或 DaemonSet
3. **证书自动续期** — 通过 systemd timer 定期检查，到期前自动 rebuild
4. **外部依赖构建时下载** — `pkgs.fetchurl` 在构建阶段下载，运行时不依赖网络
5. **版本跟随 nixpkgs** — 升级 nixpkgs 自动更新 kubernetes、istioctl 等工具版本

## 迁移过程

### 1. 项目结构

```
/home/master/Configuration/nixos/
├── flake.nix                    # 入口，定义所有主机配置
├── config/
│   ├── nodes.nix                # 集群节点定义（IP/角色/运行时）
│   └── nodes/
│       ├── dev.nix              # 开发集群（combo 节点）
│       ├── small-cluster.nix    # 小集群示例
│       └── large-cluster.nix    # 大集群示例
├── hosts/                       # 主机硬件配置
├── modules/
│   ├── server/
│   │   ├── k8s-common.nix       # K8s 基础（kubelet/证书/禁用 flannel）
│   │   ├── k8s-addons.nix       # K8s Addons（Flannel/CoreDNS/RBAC 声明式部署）
│   │   ├── k8s-control.nix      # 控制平面（apiserver/scheduler/controllerManager）
│   │   ├── k8s-worker.nix       # 工作节点
│   │   ├── k8s-lib.nix          # 节点构建工具函数
│   │   ├── istio-gateway.nix    # Istio + Gateway API（含 cleanup 服务）
│   │   ├── cert-manager.nix     # Cert-Manager + Issuers
│   │   ├── crio.nix             # CRI-O 运行时
│   │   └── containerd.nix       # Containerd 运行时
│   └── common/                  # 通用配置
└── home/                        # Home Manager 配置
```

### 2. 节点角色

- **control** — 仅运行控制平面（apiserver, scheduler, controllerManager, etcd）
- **worker** — 仅运行 kubelet + kube-proxy，调度普通 Pod
- **combo** — 同时运行控制平面和工作节点（适合小集群）

### 3. 部署命令

```bash
# 本地构建并部署到远程节点
nixos-rebuild switch \
  --flake .#dev__dxserver \
  --target-host root@dxserver \
  --build-host root@dxserver
```

## 遇到的问题与解决方案

### 问题 1：kube-proxy 未启用

**现象**: ClusterIP 无法访问，DNS 解析失败，NodePort 不通
**原因**: NixOS kubernetes 模块的 `services.kubernetes.proxy.enable` 需要依赖 `easyCerts` 或手动证书配置。未启用 easyCerts 时，kube-proxy 客户端证书未生成，systemd 服务无法启动
**解决**: 启用 `services.kubernetes.easyCerts = true`，模块自动管理 kube-proxy systemd 服务

### 问题 2：kubelet DNS 配置缺失

**现象**: Pod 无法解析 `*.svc.cluster.local`
**原因**: `clusterDns` 和 `clusterDomain` 未配置
**解决**: 在 k8s-common.nix 中添加：
```nix
services.kubernetes.kubelet = {
  clusterDns = [ "10.0.0.254" ];
  clusterDomain = "cluster.local";
};
```

### 问题 3：运行时下载外部资源超时

**现象**: `deploy-gateway-api-crds.service` 下载 GitHub CRD 超时，Flannel manifest 同理
**原因**: 服务器无法直接访问 GitHub
**解决**: 改用 `pkgs.fetchurl` 在 Nix 构建阶段下载，运行时从 /nix/store 读取：
```nix
gatewayApiCrdFile = pkgs.fetchurl {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml";
  hash = "sha256-c7kbd/a+AjqMkslp/GZOW9OxoorqWerJ68kEYHNU2tI=";
};
```

### 问题 3.5：Flannel 部署（已重构为 k8s-addons.nix）

**旧方案**: `kube-flannel-apply.service`（独立的 systemd oneshot 服务）

**新方案**: `k8s-addons-apply.service`（统一管理所有 K8s Addons）

**核心改进**：
1. API Server 就绪等待（12 次 × 10 秒重试）
2. 自动删除 NixOS 创建的冲突 ClusterRoleBinding（User → ServiceAccount）
3. 自动删除旧 DaemonSet 再重建（selector 不可变）
4. Flannel manifest + CIDR patch + CoreDNS env patch 一站式完成
5. Server-Side Apply (`--server-side --force-conflicts`) 确保幂等
6. CoreDNS 使用 `kubectl patch --type=strategic` 配合 `$setElementOrder/containers`（避免 `--type=merge` 覆盖整个 containers 数组）

**关键修复 - 双网桥冲突**：
```
问题: NixOS services.kubernetes.flannel.enable=true 自动生成 11-flannel.conf
      → 创建 mynet 网桥，与 Flannel 官方 cni0 冲突
解决: k8s-common.nix 中添加:
      services.kubernetes.flannel.enable = lib.mkForce false;
```

**关键修复 - containerd CNI 发现**：
```
问题: containerd 未配置 conf_dir/bin_dir，找不到 CNI 配置文件
      → 触发内置 mynet fallback CNI → Pod 网络不通
解决: containerd.nix 中添加:
      cni.conf_dir = "/etc/cni/net.d";
      cni.bin_dir = "/opt/cni/bin";
```

**关键修复 - 部署时序**：
```
问题: CoreDNS patch 在 Flannel 创建 cni0 之前执行 → 检测不到 IP
解决: k8s-addons.nix 中添加两步等待：
      1. kubectl rollout status daemonset kube-flannel-ds --timeout=120s
      2. for i in $(seq 1 30); do ip link show cni0 && break; sleep 2; done
```

**关键修复 - API Server TLS 证书**：
```
问题: CoreDNS 通过 10.1.1.1:6443 访问 API Server，但证书不包含此 IP
      → x509: certificate is valid for 172.178.5.123, 10.0.0.1, 127.0.0.1, not 10.1.1.1
解决: k8s-common.nix 中 extraSANs 添加 "10.1.1.1"
注意: 修改后需删除旧证书触发重新生成:
      sudo rm -f /var/lib/kubernetes/secrets/kube-apiserver*.pem
      nixos-rebuild switch
```

**关键配置**：
- `podCIDR`：集群级必填配置（如 `10.1.0.0/16`）
- manifest 通过 `pkgs.fetchurl` 在构建时下载
- 使用 `/etc/kubernetes/cluster-admin.kubeconfig` 认证
- CNI packages 包含 `pkgs.cni-plugins` + `pkgs.cni-plugin-flannel`
- 声明式创建 `10-flannel.conflist`，`cniVersion: "1.0.0"`

### 问题 3.6：istio-system 删除卡住

**现象**: `kubectl delete namespace istio-system` 永远卡在 Terminating
**原因**: Istio Gateway 资源和 IstioOperator CR 的 finalizers 阻止删除
**解决**: 添加 `cleanup-istio.service` 强制清理：
1. 遍历所有 Gateway/Istio CR 资源，移除 finalizers
2. 遍历 istio-system 命名空间所有资源，移除 finalizers
3. 强制删除命名空间（`--grace-period=0 --force`）
4. 如仍失败，提示使用 API finalize 端点手动干预

用法: `systemctl start cleanup-istio.service`

### 问题 4：CoreDNS targetPort 错误

**现象**: Pod DNS 解析超时，iptables 规则指向 `10053` 端口
**原因**: kube-dns Service 的 targetPort 配置为 10053，但 CoreDNS 实际监听 53
**解决**: 手动 patch：
```bash
kubectl get svc -n kube-system kube-dns -o json | \
  jq '.spec.ports |= map(.targetPort = 53)' | \
  kubectl replace -f -
```

### 问题 5：kube-proxy DaemonSet 镜像版本硬编码

**现象**: 手动部署的 kube-proxy 镜像版本与集群版本不匹配
**原因**: DaemonSet YAML 中硬编码了 `v1.32.4`，集群实际是 `v1.36.0`
**解决**: 改用 `${lib.getVersion pkgs.kubernetes}` 自动跟随系统版本；最终启用 easyCerts 后完全移除 DaemonSet，改由 NixOS 模块管理

### 问题 6：kubectl 硬编码证书路径

**现象**: istio-gateway.nix 和 cert-manager.nix 中 kubectl 命令硬编码了 `/var/lib/kubernetes/secrets/*.pem`
**原因**: 手动管理证书时需要指定 CA、客户端证书和密钥路径
**解决**: 启用 easyCerts 后，改用 NixOS 自动生成的 kubeconfig：
```nix
kubectl = "${pkgs.kubectl}/bin/kubectl --kubeconfig /etc/kubernetes/cluster-admin.kubeconfig";
```

### 问题 7：clusterDns 类型错误

**现象**: `services.kubernetes.kubelet.clusterDns` 报错 "not of type `list of string`"
**原因**: 该选项需要字符串列表，不是单个字符串
**解决**: `"10.0.0.254"` → `[ "10.0.0.254" ]`

### 问题 8：systemd 服务在 API Server 就绪前执行

**现象**: `k8s-addons-apply.service` / `deploy-istio.service` 启动失败，exit code 1
**原因**: systemd 服务依赖 `kubelet.service`，但 kubelet 启动 ≠ API Server 已就绪
**解决**: 所有需要访问 K8s API 的 systemd 服务添加 API Server 等待逻辑：
```bash
for i in $(seq 1 12); do
  if kubectl cluster-info --request-timeout=5s >/dev/null 2>&1; then
    break
  fi
  sleep 10
done
```

### 问题 9：Nix 字符串中的 bash 变量需要转义

**现象**: `error: undefined variable 'RETRY_INTERVAL'`
**原因**: Nix 的 `''...''` 缩进字符串中，`${VAR}` 被当作 Nix 变量插值
**解决**: bash 变量使用 `''${VAR}` 转义：
```nix
# 错误
echo "Retrying in ${RETRY_INTERVAL}s..."

# 正确
echo "Retrying in ''${RETRY_INTERVAL}s..."
```

### 问题 10：set-external-traffic-policy 服务失败

**现象**: 尝试 patch istio-ingressgateway Service 时失败
**原因**: 服务只等待 istio-system namespace 存在，不等 Service 实际创建
**解决**: 改为等待 `kubectl get svc istio-ingressgateway -n istio-system` 返回成功（最多 3 分钟）

### 问题 11：containerd 使用内置 fallback CNI

**现象**: `mynet` 网桥持续存在，Pod 网络不通，CoreDNS CrashLoopBackOff
**原因**: `containerd.nix` 未配置 `cni.conf_dir` 和 `cni.bin_dir`，containerd 找不到 NixOS 声明式创建的 CNI 配置文件（`/etc/cni/net.d/10-flannel.conflist`）
**解决**: containerd.nix 中添加：
```nix
virtualisation.containerd.settings.plugins."io.containerd.grpc.v1.cri" = {
  cni.conf_dir = "/etc/cni/net.d";
  cni.bin_dir = "/opt/cni/bin";
};
```
**注意**: 修改后必须重启 containerd 并删除已存在的 Pod（它们使用旧 CNI 创建）：
```bash
sudo systemctl restart containerd
kubectl delete pods -n kube-system --all --grace-period=0 --force
```

### 问题 12：CoreDNS 无法通过 TLS 连接 API Server

**现象**: CoreDNS 日志报 `x509: certificate is valid for 172.178.5.123, 10.0.0.1, 127.0.0.1, not 10.1.1.1`
**原因**: CoreDNS 通过 `KUBERNETES_SERVICE_HOST=10.1.1.1`（cni0 桥接 IP）连接 API Server，但 API Server 证书不包含此 IP
**解决**: k8s-common.nix 中 `extraSANs` 添加 `"10.1.1.1"`
**注意**: 证书更新后需重启 API Server：
```bash
sudo systemctl restart kube-apiserver
```

### 问题 13：Istio install 不支持 --wait=false

**现象**: `deploy-istio.service` 启动失败，exit code 64/USAGE
**原因**: 当前 istioctl 版本不再支持 `--wait=false` 标志
**解决**: 移除 `--wait=false` 参数，istioctl install 默认会等待资源就绪

### 问题 14：CoreDNS patch 覆盖容器镜像字段

**现象**: `kubectl patch --type=merge` 后 CoreDNS Deployment 的 image 字段丢失
**原因**: `--type=merge` 直接替换了整个 containers 数组，未保留原有字段
**解决**: 改用 Strategic Merge（默认类型），配合 `$setElementOrder/containers` 指定容器顺序：
```bash
kubectl patch deployment coredns -n kube-system \
  -p '{"spec":{"template":{"spec":{"$setElementOrder/containers":[{"name":"coredns"}],"containers":[...]}}}}'
```

## 回滚方案

如果 NixOS 配置导致问题：

```bash
# 查看可用的系统代
nix-env --list-generations --profile /nix/var/nix/profiles/system

# 回滚到上一代
nix-env --rollback --profile /nix/var/nix/profiles/system

# 或通过 GRUB 菜单选择上一代启动
```

## 参考

- NixOS Kubernetes 模块: `/nix/store/*/source/nixos/modules/services/cluster/kubernetes/`
- 项目路径: `/home/master/Configuration/nixos`
- Ansible 旧配置: `/home/master/world/deployment/ansible`
