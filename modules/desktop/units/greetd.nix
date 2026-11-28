# 登录管理器：greetd + tuigreet（TUI，直接跑在 VT 上，不依赖合成器）
# 归属：base 引入 = 桌面系统都有登录屏；qemu profile 额外设 initial_session 免密进 niri。
# 为什么不用图形 greeter（cosmic-greeter/gtkgreet/regreet）：都要先起一个合成器才能显示，
# 链路更长更脆；tuigreet 是"内核 VT → greetd → TUI 密码 → niri-session"最短路径。
{ pkgs, user, ... }:
{
  services.greetd = {
    enable = true;
    # TUI greeter 需要 StandardInput=tty，否则键盘输入到不了 tuigreet
    useTextGreeter = true;
    settings = {
      terminal.vt = 1;
      default_session = {
        user = "greeter";
        # --remember 的状态写在 /var/cache/tuigreet，nixpkgs 的 greetd 模块
        # 已经用 tmpfiles 建好（greeter:greeter），不用自己加。
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --asterisks"
          + " --power-shutdown '${pkgs.systemd}/bin/systemctl poweroff'"
          + " --power-reboot '${pkgs.systemd}/bin/systemctl reboot'"
          + " --cmd ${pkgs.niri}/bin/niri-session";
      };
    };
  };
}