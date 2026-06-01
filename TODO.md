# ISO
nixosanywhere 专用ISO，默认开启ssh，内置公钥。也可以像普通iso一样安装，无头模式，内置扩展cli工具，包括nushell helix，不要任何gui相关软件。体积尽量小

# linux智能拼音输入法 alphaim
在 NixOS 上追求“预编译二进制”是非常明智的选择。NixOS 默认的源码构建机制对于输入法这种需要频繁迭代、依赖复杂的 C++/AI 项目来说，编译时间过长且容易因依赖变动导致构建失败。

针对 AlphaIM（或同类未进官方源的现代输入法），基于预编译二进制的最佳 NixOS 方案是 “Flake + FHS 容器封装” 或 “AppImage 集成”。这两种方式均直接复用上游发布的二进制产物，实现秒级部署与原子化更新。

方案一：Flake + buildFHSEnv（⭐ 首选推荐）
这是 NixOS 社区处理闭源/预编译二进制输入法的标准范式。通过 buildFHSEnv 创建一个符合 FHS 标准的轻量沙箱，让预编译的 AlphaIM 二进制文件能正确找到 /lib、/usr/share 等运行时依赖，同时保持 NixOS 系统的纯净性。

flake.nix 配置模板
{
  description = "AlphaIM Prebuilt Binary for NixOS";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # 若 AlphaIM 提供 flake，直接引用；否则用本地路径或 tarball
    # alphaim-bin.url = "github:/AlphaIM/releases/download/v1.0/alphaim-linux-x86_64.tar.gz";
  };

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.{system};
    
    # 封装预编译二进制为 FHS 环境
    alphaim-fhs = pkgs.buildFHSEnv {
      name = "alphaim";
      targetPkgs = p: with p; [
        fcitx5 qt6.qtbase qt6.qtwayland dbus libxkbcommon wayland
        # 根据 AlphaIM 实际 ldd 结果补充缺失的动态库
      ];
      runScript = "{./bin/alphaim-engine}"; # 指向预编译二进制路径
      extraInstallCommands = ''
        mkdir -p out/share/applications out/share/icons/hicolor/256x256/apps
        cp {./AlphaIM.desktop} out/share/applications/
        cp {./icons/alphaim.png} out/share/icons/hicolor/256x256/apps/
      '';
    };
  in {
    nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ({ config, ... }: {
          i18n.inputMethod = {
            enabled = "fcitx5";
            fcitx5.addons = [ alphaim-fhs ];
          };
          # 确保环境变量正确注入
          environment.sessionVariables = {
            GTK_IM_MODULE = "fcitx5";
            QT_IM_MODULE = "fcitx5";
            XMODIFIERS = "@im=fcitx5";
          };
        })
      ];
    };
  };
}

方案二：AppImage 直接集成（最省事）
如果 AlphaIM 官方提供了 AppImage 格式发布包，这是零编译、零依赖冲突的终极方案。NixOS 对 AppImage 有原生支持，只需将其注册为系统包即可。

在 configuration.nix 或 home-manager 中添加
environment.systemPackages = with pkgs; [
  (appimageTools.wrapType2 {
    name = "alphaim";
    src = fetchurl {
      url = "https://github.com//AlphaIM/releases/download/v1.0/AlphaIM-x86_64.AppImage";
      sha256 = "sha256-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=";
    };
    # 自动提取桌面文件和图标
    extract = true;
  })
];

⚠️ 关键注意事项

1.  动态库兼容性验证
    预编译二进制最大的风险是 glibc/libstdc++ 版本不匹配。在封装前务必执行：
        # 检查二进制依赖
    ldd ./alphaim-engine | grep "not found"
    # 检查 glibc 版本要求
    readelf -V ./alphaim-engine | grep GLIBC_
    
    若发现缺失库，在 buildFHSEnv.targetPkgs 中补全；若 glibc 版本高于当前 nixpkgs，需切换到更新的 channel 或使用 steam-run 作为兜底运行器。

2.  IBus/Fcitx5 插件接口对齐
    AlphaIM 的二进制必须与系统中安装的 fcitx5/ibus 主程序版本兼容。建议在 targetPkgs 中显式锁定与系统一致的框架版本，避免 ABI 不匹配导致输入法无法加载。

3.  Wayland 特殊处理
    若在 Wayland 下使用，需在 FHS 环境中额外注入：
        profile = ''
      export GDK_BACKEND=wayland
      export QT_QPA_PLATFORM=wayland
      export GLFW_IM_MODULE=ibus  # 终端模拟器兼容
    '';
    

4.  更新策略
    预编译方案的优势在于可快速切换版本。建议将版本号与哈希值参数化，配合 nix flake update 实现一键升级：
        # 在 flake.nix 顶部定义
    alphaimVersion = "1.0.3";
    alphaimSha256 = "sha256-...";
    

💡 为什么不建议用 nixpkgs 源码构建？
维度           预编译二进制 (FHS/AppImage)   nixpkgs 源码构建
部署耗时       < 5 秒                        10-30 分钟
依赖稳定性     ✅ 上游已验证                 ❌ nixpkgs 更新易破坏
AI 模型文件    ✅ 随二进制分发               ❌ 需单独 fetch 并拼接
维护成本       仅更新 URL+Hash               需持续 patch/fix build
适用场景       个人桌面、快速尝鲜            服务器、多机统一部署

行动建议：
1.  先确认 AlphaIM 是否提供 .tar.gz 或 .AppImage 预编译包。
2.  若有，优先采用 方案二（AppImage），零配置即用。
3.  若仅有裸二进制，采用 方案一（FHS），按 ldd 结果补全依赖。
4.  将封装好的 derivation 提交至个人 Flake 仓库，后续通过 nix flake update 管理版本。

需要我帮您分析 AlphaIM 具体某个预编译包的 ldd 输出，或直接生成一份可运行的完整 Flake 项目结构吗？
# funasr
# 更新文档
