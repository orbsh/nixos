# Nomad CLI（只装命令行，本机不跑 agent）
#
# 用 packages/nomad.nix 的官方预编译包，不是 pkgs.nomad（后者是源码构建，
# BUSL 不进二进制缓存）。集群 endpoint 是环境事实，不进模块：在 shell 或
# 项目 .envrc 里设
#   export NOMAD_ADDR=http://<server>:4646   # 开了 ACL 还要 NOMAD_TOKEN
{ pkgs, ... }:

let
  nomad = pkgs.callPackage ../../../packages/nomad.nix { };
in
{
  environment.systemPackages = [ nomad ];
}