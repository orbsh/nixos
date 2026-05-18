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
│   │   ├── k8s-common.nix       # K8s 通用配置（kubelet/flannel/proxy/easyCerts）
│   │   ├── k8s-control.nix      # 控制平面（apiserver/scheduler/controllerManager）
│   │   ├── k8s-worker.nix       # 工作节点
│   │   ├── k8s-lib.nix          # 节点构建工具函数
│   │   ├── istio-gateway.nix    # Istio + Gateway API
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

### 问题 3.5：Flannel 部署

**方案**: `kube-flannel-apply.service`（NixOS 管理的 systemd oneshot 服务）

**部署流程**：
1. 删除旧 DaemonSet（`selector` 字段不可变，必须先删后建）
2. `kubectl apply` 官方 manifest（创建 ConfigMap + DaemonSet）
3. Patch ConfigMap 的 `net-conf.json`，将 `Network` 替换为集群级 `podCIDR` 配置
4. 重启 flannel pod 使其读取新配置

**关键配置**：
- `podCIDR`：集群级必填配置（如 `10.1.0.0/16`），必须包含各节点的 PodCIDR
- manifest 通过 `pkgs.fetchurl` 在构建时下载，避免运行时网络问题
- 使用 `/etc/kubernetes/cluster-admin.kubeconfig` 进行认证

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

## 待办事项

- [ ] 配置 SMTP 邮件通知，替换 cert auto-renew 脚本中的 TODO
- [ ] 验证 multi-node 集群的证书自动续期是否正常工作
- [ ] 考虑将 NixOS 配置文件同步到服务器（目前可能在本地管理）
- [ ] 评估是否需要保留 Ansible 作为 NixOS 的补充（如一次性任务）

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
