# TODO - 待办事项

## Kubernetes 相关

### apiserver PEM 序列化 bug 检查
- **来源**: [metrics-server-configmap-pem-bug.md](./docs/memos/metrics-server-configmap-pem-bug.md)
- **待办**: 升级 Kubernetes 版本后，检查 apiserver v1.36 的 PEM 序列化 bug 是否已在上游修复
- **操作**: 若已修复，可移除 `modules/k8s/k8s-common.nix` 中的 `fix-extension-apiserver-auth-certs` 服务
- **检查方法**:
  1. 升级 K8s 版本
  2. 停止 fix-extension-apiserver-auth-certs 服务
  3. 重启 kube-apiserver
  4. 检查 `extension-apiserver-authentication` ConfigMap 的 `requestheader-client-ca-file` 字段是否正常（多行 PEM 格式）
  5. 测试 `kubectl top nodes` 是否正常工作
