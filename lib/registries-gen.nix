# 生成 /etc/containers/registries.conf TOML 内容
# 输入：lib + containersCfg（来自 config.containersCfg）
{ lib, cfg }:
''
  unqualified-search-registries = ["docker.io"]

  # 代理镜像配置
'' + lib.concatStringsSep "\n" (lib.mapAttrsToList (prefix: location: ''
  [[registry]]
  prefix = "${prefix}"
  location = "${location}"
'') cfg.proxyRegistries) + "\n\n" +
lib.concatStringsSep "\n" (map (loc: ''
  [[registry]]
  insecure = true
  location = "${loc}"
'') cfg.insecureRegistries) + "\n"
