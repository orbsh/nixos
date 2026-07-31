# TODO - 待办事项

## Kubernetes 相关

~~### apiserver PEM 序列化 bug 检查~~ ✅ 已完成 (2026-06-30)
- **结论**: v1.36.2 已修复此 bug，重启 apiserver 后 PEM 保持正确格式（21 行）
- **操作**: 已从 `profiles/k8s/k8s-common.nix` 移除 `fix-extension-apiserver-auth-certs` 服务
- **备注**: v1.36.1 写 ConfigMap 时丢失 PEM 换行，v1.36.2 不再复现
