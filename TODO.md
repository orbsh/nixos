# TODO - 待办事项

## Kubernetes 相关

~~### apiserver PEM 序列化 bug 检查~~ ✅ 已完成 (2026-06-30)
- **结论**: v1.36.2 已修复此 bug，重启 apiserver 后 PEM 保持正确格式（21 行）
- **操作**: 已从 `profiles/k8s/k8s-common.nix` 移除 `fix-extension-apiserver-auth-certs` 服务
- **备注**: v1.36.1 写 ConfigMap 时丢失 PEM 换行，v1.36.2 不再复现
- **遗留清理 (2026-11-09)**: `modules/k8s/assets/metrics-server.yaml` 里当初加的 `metrics-server:front-proxy-client` RBAC fallback 一并删除；已 apply 到集群的对象不会因清单删项而消失，需手工 `kubectl delete clusterrole/clusterrolebinding metrics-server:front-proxy-client`

## 临时补丁：等 nixpkgs 修复进 nixos-unstable 后撤销

锁定的 nixpkgs rev `f4a03c0`（2026-11-07 09:04Z）上有两个包构建失败（cache 里也没有替代产物），
修复都已合入 `master`，但 `nixos-unstable` 一直停在同一个 rev。下表的 commit 进入 `nixos-unstable`
后，删掉对应补丁、回归 nixpkgs 原包。

先确认 `nixos-unstable` 当前推进到哪，再逐条对照时间点：

```
python3 - <<'EOF'
import json, datetime
d = json.load(open('flake.lock'))
for k, v in d['nodes'].items():
    if 'locked' in v and k.startswith('nixpkgs'):
        print(k, v['locked']['rev'], datetime.datetime.utcfromtimestamp(v['locked']['lastModified']).isoformat())
EOF
curl -s https://api.github.com/repos/NixOS/nixpkgs/branches/nixos-unstable   # HEAD 与上游提交时间对比
```

| 包 | 本 rev 现象 | 本地补丁 | 撤销条件（master 上的上游修复） |
|---|---|---|---|
| mitmproxy 12.3.0 | `test_emudhra` 的 SHA-1 根证书链被 OpenSSL 3.5 拒绝（2 个参数化用例） | `modules/dev/units/net-tools.nix` 的 `disabledTests` 增补 | `88435c45`「mitmproxy: 12.3.0 -> 12.3.1」（2026-11-07 14:32Z） |
| tree-sitter-language-pack 1.4.1 | 同上，`zstd-sys` 缺 `pkg-config` | `modules/dev/units/python.nix` 补 `pkg-config` + 系统 `zstd` | `b99641c4`「tree-sitter-language-pack: fix build with sys libs」（2026-11-07 16:46Z） |

rustfs 已从本表移出：预编译二进制是常设形态（`modules/services/rustfs.nix` 的 pinned，由 `scripts/upstream.yml` 维护），
上游配方修好也不回归 nixpkgs——源码包 47 个自研 crate，每次 bump 都要本机全量编译。

不是坏包、不用撤销的一条：`modules/dev/units/data-tools.nix` 把 pyiceberg 的 `nativeCheckInputs` 清空
（测试 extra 链 geoarrow → geopandas → mapclassify → scikit-learn → narwhals 会拖进 494MB 的 pyspark；
只设 `doCheck = false` 不够，checkInputs 仍是 drv 输入）。若以后要本机跑 pyiceberg 测试，再恢复。
