{ pkgs, lib, ... }: {
  # ── System State Version ─────────────────────────────────
  # Set once on initial install, never change unless doing a major version upgrade.
  # All hosts inherit this value from base.nix.
  system.stateVersion = "26.05";

  # 全局允许非自由软件
  nixpkgs.config.allowUnfree = true;

  # Locale & time
  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "en_US.UTF-8";

  # sudo 免密码（wheel 组）
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
    extraConfig = ''
      Defaults secure_path="/run/wrappers/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin"
    '';
  };

  # root 账号锁定
  users.users.root = {
    hashedPassword = "!";
    initialHashedPassword = lib.mkForce null;  # 清除默认的空字符串，消除多密码选项警告
  };

  # SSH：仅允许密钥登录
  services.openssh = {
    enable = true;
    settings = {
      Port = 2222;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # sysctl
  boot.kernel.sysctl = {
    "vm.swappiness"                    = 10;
    "vm.vfs_cache_pressure"            = 50;
    "vm.dirty_ratio"                   = 30;
    "vm.dirty_background_ratio"        = 10;
    "fs.file-max"                      = 1000000;
    "fs.inotify.max_user_watches"      = 524288;
    # 以下参数常与 kubernetes/kubelet 等模块重复，使用 mkDefault 避免冲突
    "net.ipv4.ip_forward"              = lib.mkDefault 1;
    "net.ipv6.conf.all.forwarding"     = lib.mkDefault 1;
    "net.ipv4.tcp_congestion_control"  = "bbr";
    "net.core.default_qdisc"           = "fq";
    "net.core.rmem_max"                = 16777216;
    "net.core.wmem_max"                = 16777216;
    "net.ipv4.tcp_rmem"                = "4096 87380 16777216";
    "net.ipv4.tcp_wmem"                = "4096 65536 16777216";
    # TCP keepalive: 防止中间设备因 idle timeout 断开长连接（registry push、DB 连接池等）
    "net.ipv4.tcp_keepalive_time"      = 30;
    "net.ipv4.tcp_keepalive_intvl"     = 10;
    "net.ipv4.tcp_keepalive_probes"    = 6;
  };

  # 基础 CLI 工具（所有主机通用）
  environment.systemPackages = with pkgs; [
    # ── 网络与传输 ──
    git curl wget rsync socat netcat-openbsd
    # ── 文件与系统工具 ──
    util-linux  # mount, fdisk, lsblk 等
    jq tree file unzip fd ripgrep bind dust  # bind: dig, nslookup

    # ── 终端与编辑器 ──
    nushell  # 现代 Shell
  ];
}
