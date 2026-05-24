{ pkgs, inputs, ... }: {
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
    htop bottom
    websocat iproute2 net-tools iputils
    patch zip
    s3fs sqlite

    # ── common/network.nix ───────────────────────────────
    netcat openresolv

    # ── 隐式包：common/sys.nix ──────────────────────────
    # networking.networkmanager.enable, services.pipewire.enable
    networkmanager pipewire wireplumber

    # ── common/container.nix ─────────────────────────────
    buildah skopeo

    # ── gui/desktop.nix ──────────────────────────
    wl-clipboard

    # ── gui/apps-core.nix ────────────────────────
    ghostty alacritty neovim neovide zed-editor
    qutebrowser
    freefilesync smplayer krita blender flameshot
    # vivaldi
    # calibre

    # ── gui/apps-im.nix ──────────────────────────
    # wechat-uos telegram-desktop

    # ── gui/apps-extra.nix ───────────────────────
    surrealist zathura foliate

    # ── dev/ ─────────────────────────────────────────────
    bun uv python3
    python3Packages.virtualenv
    python3Packages.httpx python3Packages.fastapi python3Packages.uvicorn python3Packages.websockets
    python3Packages.aiofile python3Packages.aiostream
    python3Packages.ty python3Packages.debugpy python3Packages.pytest
    python3Packages.ipython python3Packages.typer
    python3Packages.polars python3Packages.lancedb
    python3Packages.pydantic python3Packages.pydantic-graph python3Packages.pydantic-settings
    python3Packages.pyparsing python3Packages.jinja2 python3Packages.boltons python3Packages.decorator python3Packages.shortuuid
    python3Packages.structlog python3Packages.python-json-logger python3Packages.pyyaml
    python3Packages.zstandard
    vscode-langservers-extracted yaml-language-server
    rustup cargo rustc rustfmt clippy rust-analyzer sccache
    haskellPackages.ghc haskellPackages.cabal-install
    haskellPackages.stack haskellPackages.haskell-language-server
    wasmtime gcc cmake gnumake pkg-config
    kubectl kubernetes-helm

    # ── gui/laptop.nix ───────────────────────────
    brightnessctl auto-cpufreq

    # ── gui/wireguard.nix / server/wireguard.nix ─
    wireguard-tools

    # ── 隐式包：common/container.nix ────────────────────
    # virtualisation.podman.enable = true
    podman

    # ── 隐式包：common/users.nix ────────────────────────
    # programs.wireshark.package = pkgs.wireshark
    wireshark
    # services.printing.enable
    cups

    # ── 隐式包：server/k8s-common.nix ───────────────────
    # virtualisation.cri-o.enable = true, pkgs.crun
    cri-o crun

    # ── 隐式包：gui/input-method.nix ────────────
    # fcitx5 输入法全家桶
    fcitx5 fcitx5-gtk fcitx5-rime qt6Packages.fcitx5-chinese-addons

    # ── 隐式包：gui/fonts.nix ───────────────────
    noto-fonts noto-fonts-cjk-sans noto-fonts-color-emoji lilex
    nerd-fonts.jetbrains-mono

    # ── 隐式包：gui/laptop.nix ──────────────────
    # services.power-profiles-daemon.enable, services.blueman.enable
    power-profiles-daemon blueman

    # ── 隐式包：gui/cosmic.nix ──────────────────
    xdg-desktop-portal-cosmic cosmic-greeter

    # ── 隐式包：gui/hyprland.nix（条件启用） ─────
    waybar wofi mako grim slurp swappy hyprpaper cliphist wlogout swaylock-effects playerctl networkmanagerapplet pavucontrol xdg-desktop-portal-gtk
    (python3.withPackages (ps: [ ps.pyyaml ]))

    # ── disko 离线支持 ───────────────────────────────
    inputs.disko.packages.${pkgs.stdenv.hostPlatform.system}.disko
    gptfdisk dosfstools xfsprogs e2fsprogs
  ];
}
