{ pkgs, lib, ... }:

# Blender 扩展 & 插件：以「System 扩展」+「System 脚本」形式随 Blender 由 Nix 管理。
# 参考 fabricario 架构文档（ARCHITECTURE.md「关键插件生态」），把流水线依赖的开源
# 插件打进 Blender 的 system 仓库目录，重启后即用，无需在 Blender 内手动启用、也
# 不污染用户配置。插件版本固化为下方 commit。
#
# 两种机制：
# - 新式扩展（Blender 4.2+ 的 extension 结构，含 manifests）：经 BLENDER_SYSTEM_EXTENSIONS。
# - 旧式插件（legacy addon，目录含 __init__.py 或单文件 .py）：经 BLENDER_SYSTEM_SCRIPTS
#   指向含 addons/ 的目录加载（Blender 5.2 已移除自带 addons/，但 BLENDER_SYSTEM_SCRIPTS
#   仍会扫描其下 addons/ 子目录）。
#
# MPFB2 资产库：MPFB2 的大头资产（衣服/皮肤/眼睛/头发/姿势等）以 asset pack zip
# 分发，解压后就是一个「数据根」（顶层含 clothes/ skins/ hair/ 等子目录）。这里把
# 必备的 makehuman_system_assets（CC0）固定版本打包进 /nix/store，并通过
# MPFB_SECOND_ROOT 环境变量让 MPFB2 把该目录识别为附加资产根（second root）。
# 由于该路径本应配置在 Blender 偏好里（userpref.blend，不受 Nix 管控），故用补丁
# 让 MPFB2 优先读取环境变量，见 patch_mpfb_second_root.py。
{
  # ── 插件源码（GitHub 固定 commit，声明的 sha256 保证可复现）──
  config = let
    # 新式 System 扩展（含 manifest 的 extension）
    plugins = [
      {
        id = "mpfb";              # MPFB2：人物模型生成（插件体在 src/mpfb 子目录）
        src = builtins.fetchTarball {
          name = "47deded84aba2c43238cc90efdcf0421ba7c5f46.tar.gz";
          url = "https://github.com/makehumancommunity/mpfb2/archive/47deded84aba2c43238cc90efdcf0421ba7c5f46.tar.gz";
          sha256 = "0pp2vb36hi0mqdxvbq3pjpdwdjmzqczsfrsm2k709zsaknsvfzl6";
        };
        subdir = "src/mpfb";
        patchLocationservice = true;
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

    # 旧式 System 插件（legacy addon），放置于 <scripts>/addons/ 下。
    # file == true 表示为单文件插件（需为合法 Python 标识符名，连字符会无法 import）。
    # 注意：统一用 pkgs.fetchzip（对解压后内容哈希，可复现），而非 builtins.fetchTarball
    # （对 gzip 字节哈希，GitHub 归档含时间戳不可复现）。fetchzip 默认剥掉顶层目录。
    legacyAddons = [
      {
        name = "celtic_knot";        # Celtic Knot：生成凯尔特结曲线/管道
        src = pkgs.fetchzip {
          url = "https://github.com/BorisTheBrave/celtic-knot/archive/f9c653351d32d5dec61b48ae8100bd0c345607b4.tar.gz";
          sha256 = "1z3723vf89yjsnqcw0rhv6kk6bapwbiaws3zzp55vpxwnaasw2zh";
        };
        file = "celtic-knot.py";     # 单文件，安装时改名为 celtic_knot.py
      }
      {
        name = "mesh_maze";          # Mesh Maze：基于网格生成迷宫
        src = pkgs.fetchzip {
          url = "https://github.com/elfnor/mesh_maze/archive/1376c502028d32085b8defc1c4028328040e5f3e.tar.gz";
          sha256 = "1q4cj1r9yq2a3y32xizrkc82p1pv1bhjh58806bs58irbma4qjhs";
        };
        subdir = ".";
      }
      {
        name = "modular_tree";       # Modular Tree：程序化树木生成
        src = pkgs.fetchzip {
          url = "https://github.com/MaximeHerpin/modular_tree/archive/36d556111c1b0784220f2035d053688bc8def4a5.tar.gz";
          sha256 = "15mlg90s9kjnfx47zydlbvymmhm2ywi76jxx3rbva9hhlcvqgb5d";
        };
        subdir = ".";
      }
      {
        name = "SpaceshipGenerator"; # Spaceship Generator：程序化飞船生成
        src = pkgs.fetchzip {
          url = "https://github.com/a1studmuffin/SpaceshipGenerator/archive/0fe0149c9d033ac53829c3ace8dddef97209f53c.tar.gz";
          sha256 = "01hvrb0qddiy12yyaqcf5srlx3jd4iic143s5rmr4lbjnyg5nmkz";
        };
        subdir = ".";
      }
      {
        name = "bookGen";            # BookGen：批量生成摆放书籍
        src = pkgs.fetchzip {
          url = "https://github.com/oweissbarth/bookGen/archive/aceeea791d1480dd17c1d8aa7fb849defb792098.tar.gz";
          sha256 = "01ii981hv06zr31q6zv820jbi8fc60ylxlfr4wabmgdm3npr5maz";
        };
        subdir = "bookGen";
      }
      {
        name = "fspy_blender";       # fSpy：导入 fSpy 相机/背景
        src = pkgs.fetchzip {
          url = "https://github.com/stuffmatic/fSpy-Blender/archive/eec40b085d45cc623fd379998d85b88de679d4b8.tar.gz";
          sha256 = "0g1sqx4w2ksphingifj8w72hwd4c576801fj32c8p4wsplaax43h";
        };
        subdir = "fspy_blender";
      }
    ];

    # ── MPFB2 系统资产库（asset pack，CC0）──
    # 顶层解压后即数据根：clothes/ skins/ hair/ eyes/ eyebrows/ eyelashes/ teeth/
    # tongue/ proxymeshes/ poses/ packs/。sha256 对应 280,737,770 字节的 zip。
    mpfbAssetsZip = pkgs.fetchurl {
      url = "https://files2.makehumancommunity.org/asset_packs/makehuman_system_assets/makehuman_system_assets_cc0.zip";
      sha256 = "01q1i81cinwm81lwsvirh166d6nv58fjv7y155y7qm15irx14hmm";
    };

    mpfbAssets = pkgs.runCommand "mpfb-system-assets" {
      nativeBuildInputs = [ pkgs.unzip ];
    } ''
      mkdir -p $out
      unzip -q ${mpfbAssetsZip} -d $out
    '';

    # ── MPFB2 locationservice 补丁脚本：识别 MPFB_SECOND_ROOT 环境变量 ──
    mpfbPatch = ./patch_mpfb_second_root.py;

    # 仅含 system 扩展目录的派生，供 BLENDER_SYSTEM_EXTENSIONS 指向
    blenderPluginExt = pkgs.runCommand "blender-plugin-ext" {
      nativeBuildInputs = [ pkgs.python3 ];
    } (
      builtins.concatStringsSep "" (map (p: ''
        target=$out/share/blender/5.2/extensions/system/${p.id}
        mkdir -p $out/share/blender/5.2/extensions/system
        cp -r ${p.src}/${p.subdir} $target
        ${lib.optionalString (p.patchLocationservice or false) ''
          chmod -R u+w "$target"
          python3 ${mpfbPatch} "$target/services/locationservice.py"
        ''}
      '') plugins)
    );

    # 仅含 system 脚本目录（addons/）的派生，供 BLENDER_SYSTEM_SCRIPTS 指向
    blenderScripts = pkgs.runCommand "blender-scripts-addons" {} (
      builtins.concatStringsSep "" (map (a: if a ? file then ''
        mkdir -p $out/share/blender/5.2/scripts/addons
        cp ${a.src}/${a.file} $out/share/blender/5.2/scripts/addons/${a.name}.py
      '' else ''
        mkdir -p $out/share/blender/5.2/scripts/addons
        cp -r ${a.src}/${a.subdir} $out/share/blender/5.2/scripts/addons/${a.name}
      '') legacyAddons)
    );
  in {
    # ── overlay：包装官方 blender，注入扩展/脚本/资产根环境变量（不重编译）──
    nixpkgs.overlays = [
      (final: prev: {
        blender = pkgs.symlinkJoin {
          name = "blender-with-extensions";
          # 官方包保留 .desktop 启动器与图标；wrapper 二进制保证 CLI 带环境变量
          paths = [
            # 注意：symlinkJoin 排在前面的路径优先，wrapper 须在官方包之前，
            # 否则 bin/blender 会被官方版本覆盖，丢失环境变量。
            (pkgs.writeShellScriptBin "blender" ''
              export BLENDER_SYSTEM_EXTENSIONS=${blenderPluginExt}/share/blender/5.2/extensions
              export BLENDER_SYSTEM_SCRIPTS=${blenderScripts}/share/blender/5.2/scripts
              export MPFB_SECOND_ROOT=${mpfbAssets}
              exec "${prev.blender}/bin/blender" "$@"
            '')
            prev.blender
          ];
        };
      })
    ];

    environment.systemPackages = with pkgs; [
      blender
    ];
  };
}
