# 修复 cfssl 证书缺少 IP SAN 的问题 + 延长证书有效期 + 修改端口
# 1. NixOS kubernetes pki 模块在调用 cfssl gencert 时没有传递 -hostname 参数，
#    导致生成的证书不包含 IP SAN，certmgr 无法连接 cfssl 续期证书。
# 2. NixOS 默认证书有效期为 720h（30天），对于开发环境太短，改为 8760h（1年）。
# 3. cfssl 默认端口 8888 与 K8s NodePort (warpgate) 冲突，改为 7888。
# 此模块覆盖 cfssl 的 pre-start 脚本和配置文件。
{ pkgs, lib, config, ... }:

let
  cfg = config.services.kubernetes.pki;
  cfssl = pkgs.cfssl;
  dataDir = config.services.cfssl.dataDir;
  masterAddress = config.services.kubernetes.masterAddress;
  cfsslAPITokenPath = "${dataDir}/apitoken.secret";
in
{
  # 仅在启用 easyCerts 且是 master 节点时应用此修复
  config = lib.mkIf (config.services.kubernetes.easyCerts && builtins.elem "master" config.services.kubernetes.roles) {
    # 修改 cfssl 端口，避免与 K8s NodePort 冲突
    services.cfssl.port = lib.mkForce 7888;

    # 覆盖 cfssl 配置文件，将证书有效期从 720h（30天）改为 8760h（1年）
    services.cfssl.configFile = lib.mkForce (toString (
      pkgs.writeText "cfssl-config.json" (builtins.toJSON {
        signing = {
          profiles = {
            default = {
              usages = [ "digital signature" ];
              auth_key = "default";
              expiry = "8760h";  # 1年（原值 720h = 30天）
            };
          };
        };
        auth_keys = {
          default = {
            type = "standard";
            key = "file:${cfsslAPITokenPath}";
          };
        };
      })
    ));

    systemd.services.cfssl.preStart = lib.mkForce (
      with pkgs;
      lib.concatStringsSep "\n" [
        "set -e"
        # 生成 CA 证书（如果不存在）
        (lib.optionalString cfg.genCfsslCACert ''
          if [ ! -f "${cfg.caCertPathPrefix}.pem" ]; then
            ${cfssl}/bin/cfssl genkey -initca ${pkgs.writeText "kube-pki-cacert-csr.json" (builtins.toJSON config.services.kubernetes.pki.caSpec)} | \
              ${cfssl}/bin/cfssljson -bare ${cfg.caCertPathPrefix}
          fi
        '')
        # 生成 cfssl API 证书（如果不存在）- 添加 -hostname 参数
        (lib.optionalString cfg.genCfsslAPICerts ''
          if [ ! -f "${dataDir}/cfssl.pem" ]; then
            ${cfssl}/bin/cfssl gencert -ca "${cfg.caCertPathPrefix}.pem" -ca-key "${cfg.caCertPathPrefix}-key.pem" -hostname "${masterAddress}" ${pkgs.writeText "kube-pki-cfssl-csr.json" (builtins.toJSON {
              key = {
                algo = "rsa";
                size = 2048;
              };
              CN = masterAddress;
              hosts = [ masterAddress ] ++ cfg.cfsslAPIExtraSANs;
            })} | \
              ${cfssl}/bin/cfssljson -bare ${dataDir}/cfssl
          fi
        '')
        # 生成 API token（如果不存在）
        (lib.optionalString cfg.genCfsslAPIToken ''
          if [ ! -f "${config.services.cfssl.dataDir}/apitoken.secret" ]; then
            install -o cfssl -m 400 <(head -c 16 /dev/urandom | od -An -t x | tr -d ' ') "${config.services.cfssl.dataDir}/apitoken.secret"
          fi
        '')
      ]
    );
  };
}
