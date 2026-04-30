# 如何运行外部二进制文件

NixOS 的动态链接器路径特殊，直接运行从外部下载或编译的二进制文件可能失败。以下是三种解决方案：

## 方案 1：使用 `nix-ld`（推荐）

这是最通用的方法，允许动态链接的二进制文件使用系统的库。

```nix
# 在 NixOS 配置模块中添加：
programs.nix-ld.enable = true;
programs.nix-ld.libraries = with pkgs; [
  stdenv.cc.cc
  zlib
  openssl
  # 根据需要添加其他库
];
```

## 方案 2：直接运行真正的静态二进制文件

完全静态编译（使用 musl libc）的二进制文件不依赖系统库，可以直接运行。

```bash
chmod +x ./static-binary
./static-binary

# 验证是否为静态链接：
file ./binary  # 输出应包含 "statically linked"
ldd ./binary   # 输出应显示 "not a dynamic executable"
```

## 方案 3：使用 `patchelf`

如果必须运行特定的动态二进制文件且不想全局配置 nix-ld，可以使用 `patchelf` 修改其解释器。

```bash
nix-shell -p patchelf
patchelf --set-interpreter "$(cat /nix/var/nix/profiles/system/sw/lib/ld-linux-x86-64.so.2)" ./binary
```
