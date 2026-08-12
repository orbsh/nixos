# Nix GC 统一策略引擎
# 三个正交维度：按代 / 按时间 / 空间阈值，独立配置，由同一 systemd 服务执行。
# - 按代/按时间：删除旧 generation（nix-env --delete-generations）
# - 空间阈值：注入 nix.settings.min-free/max-free，daemon 在磁盘满时构建/下载前自动兜底（优先保业务）
{ pkgs, lib, config, ... }:

{
  options.nix.gc = {
    keepGenerations = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "保留最近 N 代 generation（null=不按代清理）";
    };
    deleteOlderThan = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "删除超过该时间前的 generation，如 \"14d\"（null=不按时间）";
    };
    minFree = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "可用空间低于该字节数时自动清理不可达路径（磁盘满兜底）";
    };
    maxFree = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "空间清理到可用该字节数为止";
    };
  };

  config = {
    # 默认策略：按时间 30d + 空间兜底（服务器端在 profile 中覆盖为按代）
    nix.gc.keepGenerations = lib.mkDefault null;
    nix.gc.deleteOlderThan = lib.mkDefault "30d";
    nix.gc.minFree = lib.mkDefault (50 * 1024 * 1024 * 1024);
    nix.gc.maxFree = lib.mkDefault (100 * 1024 * 1024 * 1024);

    # 按代/按时间策略服务（任一启用时激活）
    nix.gc.automatic = lib.mkIf (config.nix.gc.keepGenerations != null
                                 || config.nix.gc.deleteOlderThan != null)
                                 (lib.mkDefault false);

    # 空间兜底由 daemon 层处理（磁盘满时构建/下载前触发）
    nix.settings.min-free = lib.mkIf (config.nix.gc.keepGenerations != null
                                      || config.nix.gc.deleteOlderThan != null)
                                      (lib.mkDefault config.nix.gc.minFree);
    nix.settings.max-free = lib.mkIf (config.nix.gc.keepGenerations != null
                                      || config.nix.gc.deleteOlderThan != null)
                                      (lib.mkDefault config.nix.gc.maxFree);

    systemd.services.nix-gc-policy = lib.mkIf (config.nix.gc.keepGenerations != null
                                               || config.nix.gc.deleteOlderThan != null) {
      description = "Nix GC: generation/time policy based cleanup";
      path = [ pkgs.nix pkgs.bash pkgs.coreutils pkgs.findutils ];
      script = ''
        set -euo pipefail
        keep=''${config.nix.gc.keepGenerations}
        older=''${config.nix.gc.deleteOlderThan}

        profiles="/nix/var/nix/profiles/system"
        profiles+=" $(find /nix/var/nix/profiles/per-user -maxdepth 2 \
                    \( -name 'profile' -o -name 'home-manager' \) -type l 2>/dev/null || true)"

        for prof in $profiles; do
          [ -e "$prof" ] || continue
          args=()
          if [ -n "$keep" ]; then args+=(+"$keep"); fi
          if [ -n "$older" ]; then args+=("$older"); fi
          if [ "''${#args[@]}" -gt 0 ]; then
            nix-env --profile "$prof" --delete-generations "''${args[@]}" || true
          fi
        done

        # 清理不可达路径（无按代/按时间时默认保留 30 天）
        nix-collect-garbage --delete-older-than "''${older:-30d}" || true
      '';
      serviceConfig.Type = "oneshot";
      startAt = "weekly";
    };
  };
}
