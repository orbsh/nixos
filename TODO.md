# TODO - 待办事项

## Kubernetes 相关

~~### apiserver PEM 序列化 bug 检查~~ ✅ 已完成 (2026-06-30)
- **结论**: v1.36.2 已修复此 bug，重启 apiserver 后 PEM 保持正确格式（21 行）
- **操作**: 已从 `profiles/k8s/k8s-common.nix` 移除 `fix-extension-apiserver-auth-certs` 服务
- **备注**: v1.36.1 写 ConfigMap 时丢失 PEM 换行，v1.36.2 不再复现
- **遗留清理 (2026-11-09)**: `modules/k8s/assets/metrics-server.yaml` 里当初加的 `metrics-server:front-proxy-client` RBAC fallback 一并删除；已 apply 到集群的对象不会因清单删项而消失，需手工 `kubectl delete clusterrole/clusterrolebinding metrics-server:front-proxy-client`

## 非 nixpkgs 原包的本地调整

rustfs 走预编译二进制，是常设形态（`modules/services/rustfs.nix` 的 pinned，由 `scripts/upstream.yml` 维护），上游配方修好也不回归 nixpkgs——源码包 47 个自研 crate，每次 bump 都要本机全量编译。

pyiceberg 在 `modules/dev/units/data-tools.nix` 里把 `nativeCheckInputs` 清空（测试 extra 链 geoarrow → geopandas → mapclassify → scikit-learn → narwhals 会拖进 494MB 的 pyspark；只设 `doCheck = false` 不够，checkInputs 仍是 drv 输入）。若以后要本机跑 pyiceberg 测试，再恢复。
