#!/usr/bin/env nu
# headscale.nu — headscale 管理 CLI（REST API）
#
# 环境变量:
#   HEADSCALE_URL      控制面地址，如 https://headscale.example.com
#   HEADSCALE_API_KEY  API key (headscale apikeys create 生成)
#
# 用法:
#   nu headscale.nu users list
#   nu headscale.nu users create alice
#   nu headscale.nu keys create <user_id> --reusable --days 90
#   nu headscale.nu keys list <user_id>
#   nu headscale.nu nodes list
#   nu headscale.nu nodes delete <node_id>

# 统一请求入口：组装认证头、校验环境变量、错误透传
def api [method: string, path: string, body?: any] {
    let url = $env | get --optional HEADSCALE_URL
    let key = $env | get --optional HEADSCALE_API_KEY
    if ($url == null) or ($key == null) {
        error make {msg: "HEADSCALE_URL / HEADSCALE_API_KEY 未设置"}
    }
    let headers = {
        Authorization: $"Bearer ($key)"
        Accept: "application/json"
    }
    let resp = if $body == null {
        match $method {
            "GET" => {http get $"($url)/api/v1/($path)" --headers $headers}
            "DELETE" => {http delete $"($url)/api/v1/($path)" --headers $headers}
            _ => {error make {msg: $"不支持的方法: ($method)"}}
        }
    } else {
        let payload = $body | to json
        http post $"($url)/api/v1/($path)" $payload --headers $headers --content-type "application/json"
    }
    # http 命令对 4xx/5xx 直接抛错，错误信息含原始响应，透传给调用方
    $resp
}

def main [] {}

# 用户管理
def "main users" [] {}

# 列出所有用户
def "main users list" [] {
    api GET "users" | get users? | default $in
}

# 创建用户
def "main users create" [name: string] {
    api POST "users" {name: $name}
}

# preauth key 管理
def "main keys" [] {}

# 为用户创建 preauth key（--days 过期天数，--reusable 可重复使用）
def "main keys create" [
    user_id: int
    --reusable
    --days: int = 90
] {
    let expiration = (date now) + ($days * 1day) | format date "%Y-%m-%dT%H:%M:%SZ"
    api POST "preauthkeys" {
        user: $user_id
        reusable: $reusable
        expiration: $expiration
    }
}

# 列出某用户的 preauth key
def "main keys list" [user_id: int] {
    api GET $"preauthkeys?user=($user_id)"
}

# 删除 preauth key
def "main keys delete" [key: string] {
    api DELETE $"preauthkeys/($key)"
}

# 节点管理
def "main nodes" [] {}

# 列出所有节点
def "main nodes list" [] {
    api GET "nodes" | get nodes? | default $in
}

# 删除节点记录（节点重新注册会分配新 IP，删除前确认无配置引用该 IP）
def "main nodes delete" [node_id: int] {
    api DELETE $"nodes/($node_id)"
}
