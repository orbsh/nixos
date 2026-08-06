{ pkgs, lib, ... }:

# Blender 插件：以「System 扩展」形式随 Blender 一起由 Nix 管理。
# 参考 fabricario 架构文档（ARCHITECTURE.md「关键插件生态」），把流水线依赖的
# 开源插件打进 Blender 的 system 仓库目录，重启后即用，无需在 Blender 内手动启用、
# 也不污染用户配置。插件版本固化为下方 commit。
#
# 实现：Blender 用「可执行文件解析后的真实路径」锚定 system 扩展目录，symlinkJoin
# 无法覆盖（会解析回原包）。故生成一个仅含扩展目录的派生，再用 writeShellScriptBin
# 包装官方 blender，注入 BLENDER_SYSTEM_EXTENSIONS 指向它。官方包本体不重编译。
{
  # ── 插件源码（GitHub 固定 commit，声明的 sha256 保证可复现）──
  config = let
    plugins = [
      {
        id = "mpfb";              # MPFB2：人物模型生成（插件体在 src/mpfb 子目录）
        src = builtins.fetchTarball {
          name = "47deded84aba2c43238cc90efdcf0421ba7c5f46.tar.gz";
          url = "https://github.com/makehumancommunity/mpfb2/archive/47deded84aba2c43238cc90efdcf0421ba7c5f46.tar.gz";
          sha256 = "0pp2vb36hi0mqdxvbq3pjpdwdjmzqczsfrsm2k709zsaknsvfzl6";
        };
        subdir = "src/mpfb";
      }
      {
        id = "molecularplus";     # Molecular+：粒子物理碰撞
        src = builtins.fetchTarball {
          name = "fb2e780d9fa5c166e60e66b44a6c347745167c52.tar.gz";
          url = "https://github.com/u3dreal/molecular-plus/archive/fb2e780d9fa5c166e60e66b44a6c347745167c52.tar.gz";
          sha256 = "09m7kv61nm9jv6n45pfrx5dcsn48z8zb622qx9flwzyx7riz2n0h";
        };
        subdir = ".";
      }
      {
        id = "camera_shakify";    # Camera Shakify：手持摄影抖动
        src = builtins.fetchTarball {
          name = "a59d9f91dd899dd5e8539dec1e7d5d2c69516920.tar.gz";
          url = "https://github.com/EatTheFuture/camera_shakify/archive/a59d9f91dd899dd5e8539dec1e7d5d2c69516920.tar.gz";
          sha256 = "1q40j120djw0s3k50dhq6ainj0az5kvn9h7rqqjg6yw5jgaggvaa";
        };
        subdir = ".";
      }
      {
        id = "blenderkit";        # BlenderKit：在线 3D 资产库（基础版）
        src = builtins.fetchTarball {
          name = "aeaaf53ca48ffa5d7302572f027d1ebacbfe98c7.tar.gz";
          url = "https://github.com/BlenderKit/BlenderKit/archive/aeaaf53ca48ffa5d7302572f027d1ebacbfe98c7.tar.gz";
          sha256 = "0rdjflqz7j5pz4vqlaa3cm7b8girwnwah8apmpxid36d7xpm9cyv";
        };
        subdir = ".";
      }
    ];

    # 仅含 system 扩展目录的派生，供 BLENDER_SYSTEM_EXTENSIONS 指向
    blenderPluginExt = pkgs.runCommand "blender-plugin-ext" {} (
      builtins.concatStringsSep "" (map (p: ''
        target=$out/share/blender/5.2/extensions/system/${p.id}
        mkdir -p $out/share/blender/5.2/extensions/system
        cp -r ${p.src}/${p.subdir} $target
      '') plugins)
    );
  in {
    # ── overlay：包装官方 blender，注入扩展目录环境变量（不重编译）──
    nixpkgs.overlays = [
      (final: prev: {
        blender = pkgs.writeShellScriptBin "blender" ''
          export BLENDER_SYSTEM_EXTENSIONS=${blenderPluginExt}/share/blender/5.2/extensions
          exec "${prev.blender}/bin/blender" "$@"
        '';
      })
    ];

    environment.systemPackages = with pkgs; [
      blender
    ];
  };
}
