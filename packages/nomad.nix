# Nomad CLI —— 官方预编译二进制
#
# 不用 pkgs.nomad：nixpkgs 里是 buildGoModule 源码构建，而 Nomad 是 BUSL-1.1
# （unfree），cache.nixos.org 不为它出 narinfo，装它等于本地编译整个 Go 工程。
#
# 上游二进制只在 releases.hashicorp.com（GitHub release 只有源码，没有附件），
# sha256 取自同目录的 nomad_<ver>_SHA256SUMS，fetchurl 会校验收到的文件。
{ lib, stdenv, fetchurl, unzip, installShellFiles }:

stdenv.mkDerivation (finalAttrs: {
  pname = "nomad";
  version = "1.11.3";

  src = fetchurl {
    url = "https://releases.hashicorp.com/nomad/${finalAttrs.version}/nomad_${finalAttrs.version}_linux_amd64.zip";
    hash = "sha256-GdrFZCorpTBeb/jv7ganCNdg6+TRzXk2vD3FJvR33BI=";
  };

  nativeBuildInputs = [ unzip installShellFiles ];

  # zip 里就一个静态链接的 nomad，没有源码树可解
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    unzip -q $src nomad -d $out/bin
    chmod +x $out/bin/nomad
    runHook postInstall
  '';

  # 官方包里不带补全，按 nomad 自带的补全命令生成
  postInstall = ''
    echo "complete -C $out/bin/nomad nomad" > nomad.bash
    installShellCompletion nomad.bash
  '';

  meta = {
    description = "Distributed, Highly Available, Datacenter-Aware Scheduler (official binary)";
    homepage = "https://developer.hashicorp.com/nomad";
    license = lib.licenses.bsl11;
    mainProgram = "nomad";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})