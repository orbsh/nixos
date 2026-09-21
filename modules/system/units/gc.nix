# Nix GC 策略：按代清理
# 单一维度 nix.gc.keepGenerations —— 保留最近 N 代，其余由 nix-env --delete-generations 删除，
# 再由 nix-collect-garbage 回收不可达路径。
#
# 为何没有「按时间」维度：nix-env --delete-generations 一次只接受一种规则
# （Nix 2.34.8：+N 与 Nd 混用直接报 invalid generation number），而按时间删除会突破
# 「至少保留 N 代」的下限——保留窗口就变成时间的函数而非数量的函数。回滚窗口只由数量定义。
#
# 为何没有「空间阈值」（min-free/max-free）：它作用于 GC 的不可达路径，不是 generation。
# 磁盘紧张时它一个代也删不掉（不可达路径清空即停，nix.conf: until max-free bytes are
# available or there is no more garbage），所以既不能替代按代策略，也不能在空间不足时把
# 代数降到 N 以下。去掉后磁盘满的表现为构建 ENOSPC，收敛时机由每周的按代清理负责。
{ pkgs, lib, config, ... }:

{
  options.nix.gc = {
    keepGenerations = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "保留最近 N 代 generation（null=不清理 generation）";
    };
  };

  config = {
    # 默认：保留最近 10 代（与 systemd-boot configurationLimit 默认值一致）
    nix.gc.keepGenerations = lib.mkDefault 10;

    # 启用时关闭上游 nix.gc.automatic，清理由本服务负责
    nix.gc.automatic = lib.mkIf (config.nix.gc.keepGenerations != null)
                                 (lib.mkDefault false);

    systemd.services.nix-gc-policy = lib.mkIf (config.nix.gc.keepGenerations != null) {
      description = "Nix GC: generation count policy based cleanup";
      path = [ pkgs.nix pkgs.bash pkgs.coreutils pkgs.findutils ];
      script = ''
        set -euo pipefail
        keep='${lib.toString config.nix.gc.keepGenerations}'

        profiles="/nix/var/nix/profiles/system"
        profiles+=" $(find /nix/var/nix/profiles/per-user -maxdepth 2 \
                    \( -name 'profile' -o -name 'home-manager' \) -type l 2>/dev/null || true)"

        for prof in $profiles; do
          [ -e "$prof" ] || continue
          nix-env --profile "$prof" --delete-generations +"$keep" || true
        done

        # 回收上一步删掉 generation 后变为不可达的 store 路径。
        # 不带 --delete-older-than：该参数等价于按时间再删一遍 generation，会突破数量下限。
        nix-collect-garbage || true
      '';
      serviceConfig.Type = "oneshot";
      startAt = "weekly";
    };

    # 错过调度点则开机补跑：长期开机的机器 timer 一直 active，无 inactive 窗口，此项对其零影响；
    # 关机/挂起跨过周一 00:00 的机器（portable/qemu）在开机时补跑一次。
    # startAt 生成的 timer 只有 OnCalendar=weekly（不带 Persistent），故此处单独覆盖。
    # RandomizedDelaySec：每次触发（含开机补跑）在窗口内随机延迟，避免与开机 I/O 抢资源。
    systemd.timers.nix-gc-policy = lib.mkIf (config.nix.gc.keepGenerations != null) {
      timerConfig = {
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };
}