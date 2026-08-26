# 核心系统预设 + Home Manager 基础配置
{ config, lib, ... }: {
  # 共享代理地址：完整 URI（如 http://127.0.0.1:7890 或 socks5://host:port），singbox 引入时自动赋其地址；
  # 留空(null)=不走代理(直连)。定义在此(全 hosts 公共基座)使变量独立于 singbox——不引 singbox 直连，也可指向任意代理服务。
  options.proxy.address = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "代理完整地址(URI)。singbox 引入时自动设为其地址；留空 = 不走代理(直连)；也可手动指向其他代理服务";
  };

  imports = [
    ./units/sys.nix
    ./units/kanata.nix
    ./units/base.nix
    ./units/nix.nix
    ./units/gc.nix
    ./units/users.nix
    ./units/network.nix
    ./units/extra.nix
    ./units/container.nix
    ./units/nushell.nix
    ./units/systemd-compliance.nix
    ./units/hardware-generic.nix

    # Home Manager 基础（nvim、git、shell）
    ./units/home-base.nix
    ./units/home-shell.nix
    ./units/home-nvim.nix
    #./units/home-kakoune.nix
    ./units/home-git.nix
    # ./units/lsp-bridge.nix  # 已停用（lsp-bridge 为 emacs/elisp LSP 客户端；emacs 已放弃，不再需要其 Python 运行时）
  ];
}
