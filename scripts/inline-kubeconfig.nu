#!/usr/bin/env nu
# inline-kubeconfig.nu
# 直接读取系统证书，生成内联 base64 的 kubeconfig 输出到 stdout
# 用法: nu scripts/inline-kubeconfig.nu [master地址] | save ~/.kube/config

def main [master_address?: string] {
    let api_server = $master_address | default "https://127.0.0.1:6443"

    def "base64-read" [path: string] {
        open $path --raw | encode base64
    }

    let ca = base64-read "/var/lib/kubernetes/secrets/ca.pem"
    let cert = base64-read "/var/lib/kubernetes/secrets/cluster-admin.pem"
    let key = base64-read "/var/lib/kubernetes/secrets/cluster-admin-key.pem"

    let config = {
        apiVersion: "v1"
        kind: "Config"
        clusters: [
            {
                name: "local"
                cluster: {
                    server: $api_server
                    "certificate-authority-data": $ca
                }
            }
        ]
        users: [
            {
                name: "cluster-admin"
                user: {
                    "client-certificate-data": $cert
                    "client-key-data": $key
                }
            }
        ]
        contexts: [
            {
                name: "local"
                context: {
                    cluster: "local"
                    user: "cluster-admin"
                }
            }
        ]
        "current-context": "local"
    }

    $config | to yaml
}
