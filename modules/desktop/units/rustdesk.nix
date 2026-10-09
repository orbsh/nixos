# RustDesk 预编译二进制（GitHub releases, v1.5.0 sciter-free flutter deb）
{
  lib,
  pkgs,
  ...
}: let
  inherit (pkgs) stdenv;
  version = "1.5.0";
  src = pkgs.fetchurl {
    url = "https://github.com/rustdesk/rustdesk/releases/download/${version}/rustdesk-${version}-x86_64.deb";
    hash = "sha256-TiuXAdJafvNz89Cb2lhKN9aQL5emqxXy6G1KV4PioOw=";
  };
  deps = with pkgs; [
    gtk3
    glib
    gdk-pixbuf
    pango
    cairo
    atk
    libepoxy
    fontconfig
    wayland
    glib-networking
    dbus
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    pulseaudio
    xorg.libX11
    xorg.libxcb
    xorg.libXfixes
    xorg.libXtst
    libxkbcommon
    libpulseaudio
  ];

  # RustDesk 预编译二进制（GitHub releases, v1.5.0 flutter deb）
  rustdesk = stdenv.mkDerivation {
    pname = "rustdesk";
    inherit version;
    inherit src;

    nativeBuildInputs = [pkgs.dpkg pkgs.makeWrapper];

    unpackPhase = ''
      dpkg-deb -x $src .
    '';

    installPhase = ''
      mkdir -p $out
      mkdir -p $out/libexec
      cp -r usr/share/rustdesk $out/libexec/
      mkdir -p $out/bin
      # launcher so RPATH / LD_LIBRARY_PATH resolves Nix deps
      makeWrapper $out/libexec/rustdesk/rustdesk $out/bin/rustdesk \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath deps}" \
        --chdir $out/libexec/rustdesk
      # desktop entry + icons (desktop entry Exec=rustdesk resolves via PATH to the wrapper)
      mkdir -p $out/share
      cp -r usr/share/applications $out/share/applications
      cp -r usr/share/icons $out/share/icons
    '';

    meta.mainProgram = "rustdesk";
  };
in
  # 模块必须返回 option/config attrset；derivation 作为模块体返回会与
  # module 合并机制形成 config <-> pkgs 无限递归
  {
    environment.systemPackages = [rustdesk];
  }
