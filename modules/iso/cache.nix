{ pkgs, ... }: {
  # ── ISO 本地包缓存 ──────────────────────────────────────
  # 仅包含项目各模块中实际引用的包，不添加任何额外内容。
  # 安装时可直接从本地 Nix store 复制，无需联网下载。

  environment.systemPackages = with pkgs; [
    # ── common/base.nix ──────────────────────────────────
    git curl wget rsync
    jq tree file unzip fd ripgrep
    dust delta zellij helix nushell

    # ── common/extra.nix ─────────────────────────────────
    glow fzf duckdb termshark neovim
    strace tcpdump socat lsof
    websocat iproute2 net-tools iputils
    patch zip
    s3fs sqlite3

    # ── common/network.nix ───────────────────────────────
    openbsd-netcat resolvconf

    # ── common/container.nix ─────────────────────────────
    buildah skopeo

    # ── workstation/desktop.nix ──────────────────────────
    wl-clipboard

    # ── workstation/apps-core.nix ────────────────────────
    ghostty alacritty neovim neovide zed-editor
    vivaldi qutebrowser
    freefilesync smplayer krita blender flameshot calibre

    # ── workstation/apps-im.nix ──────────────────────────
    wechat-uos telegram-desktop

    # ── workstation/extra.nix ────────────────────────────
    surrealist wps-office zathura zathura-pdf-mupdf foliate

    # ── workstation/dev.nix ──────────────────────────────
    bun uv python3
    rustup cargo rustc rustfmt clippy rust-analyzer sccache
    haskellPackages.ghc haskellPackages.cabal-install
    haskellPackages.stack haskellPackages.haskell-language-server
    wasmtime gcc cmake gnumake pkg-config
    kubectl kubeadm kubernetes-helm

    # ── workstation/laptop.nix ───────────────────────────
    brightnessctl auto-cpufreq

    # ── workstation/nomad.nix / server/nomad.nix ─────────
    nomad

    # ── workstation/wireguard.nix / server/wireguard.nix ─
    wireguard-tools

    # ── 隐式包：common/container.nix ────────────────────
    # virtualisation.podman.enable = true
    podman

    # ── 隐式包：common/users.nix ────────────────────────
    # programs.wireshark.package = pkgs.wireshark
    wireshark

    # ── 隐式包：server/k8s-common.nix ───────────────────
    # virtualisation.cri-o.enable = true, pkgs.crun
    cri-o crun

    # ── 隐式包：workstation/input-method.nix ────────────
    # fcitx5 输入法全家桶
    fcitx5 fcitx5-gtk fcitx5-qt fcitx5-rime fcitx5-chinese-addons rime-wubi

    # ── 隐式包：workstation/fonts.nix ───────────────────
    noto-fonts noto-fonts-cjk-sans noto-fonts-emoji lilex wqy-zenhei

    # ── 隐式包：workstation/laptop.nix ──────────────────
    # services.power-profiles-daemon.enable, services.blueman.enable
    power-profiles-daemon blueman

    # ── 隐式包：workstation/cosmic.nix ──────────────────
    xdg-desktop-portal-cosmic cosmic-greeter

    # ── 隐式包：workstation/hyprland.nix（条件启用） ─────
    waybar wofi mako grim slurp swappy hyprpaper cliphist wlogout swaylock-effects playerctl networkmanagerapplet pavucontrol xdg-desktop-portal-gtk
  ];
}
