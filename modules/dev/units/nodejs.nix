{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # JS/TS Runtime (Primary)
    nodejs

    # JS/TS 全局工具链（LSP 服务器）
    typescript-language-server
    vscode-langservers-extracted  # JSON/HTML/CSS 语言服务器
    yaml-language-server          # YAML 语言服务器
  ];

  # 注意：TypeSpec 需手动安装：npm install -g @typespec/compiler @typespec/json-schema
  # 或创建 home-manager 配置管理 npm 全局包
}
