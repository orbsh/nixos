{ pkgs, ... }: {
  # ── 额外工具（从 base.nix 拆分） ──────────────────────
  environment.systemPackages = with pkgs; [
    # 终端增强
    glow        # markdown 渲染

    # 编辑器（访客/root 可用）
    neovim      # 通用编辑器，各机器均有

    # ── 诊断工具 ──────────────────────────────────────
    strace      # 系统调用追踪
    tcpdump     # 网络抓包
    socat       # 双向数据流
    lsof        # 列出打开文件

    # ── 网络工具 ──────────────────────────────────────
    websocat    # WebSocket CLI
    iproute2    # ip/ss 等网络管理
    net-tools   # ifconfig/netstat（传统工具）
    iputils     # ping 等
    traceroute  # 路由追踪

    # ── 文件处理 ──────────────────────────────────────
    patch       # 补丁应用
    zip         # 压缩

    # ── 存储与数据库 ──────────────────────────────────
    s3fs        # S3 文件系统挂载
    sqlite      # SQLite CLI

    # ── 系统监控 ──────────────────────────────────────
    htop        # 交互式进程查看器
    bottom      # 跨平台系统监控 (btm)
  ];
}
