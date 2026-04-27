{ pkgs, ... }: {
  # ── 额外工具（从 base.nix 拆分） ──────────────────────
  environment.systemPackages = with pkgs; [
    # 终端增强
    glow        # markdown 渲染
    fzf         # 模糊搜索

    # 数据分析
    duckdb      # 嵌入式 OLAP 数据库

    # 网络调试
    termshark   # 终端 WiShark/TShark 前端

    # 编辑器（访客/root 可用）
    neovim      # 通用编辑器，各机器均有
  ];
}