def cmpl [] {
    [
        outbounds-to-kdl
        kdl-to-config
        generate
    ]
}

export def main [
    action: string@cmpl
    --config-path: string
    --rule-bin-path: string
    --rule-prefix: string   # rule-set path 前缀重写（产物给非本机消费方时用，如容器挂载布局）
    --output: string
    --outbound-tag: string
    --clash-api: string     # 注入 experimental.clash_api.external_controller（如 127.0.0.1:7892）；不传则不生成该节点
] {
    let o = $in
    match $action {
        outbounds-to-kdl => {
            $o | from json | outbounds-to-kdl $outbound_tag
        }
        kdl-to-config => {
            $o | from kdl | kdl-to-config $rule_bin_path $rule_prefix | to json
        }
        generate => {
            let dir = $config_path
            if ($dir | path type) != "dir" {
                error make { msg: $"configDir not found: ($dir)" }
            }
            let kdls = glob ($dir)/*.kdl
            if ($kdls | is-empty) {
                error make { msg: $"no *.kdl files in configDir: ($dir)" }
            }
            let merged = $kdls | each {|f| open $f --raw | from kdl } | flatten
            let cfg = $merged | kdl-to-config $rule_bin_path $rule_prefix
            # 注入 experimental.clash_api（KDL 源不掺生成物；不传 --clash-api 则保持 KDL 原样）
            let cfg = if ($clash_api | is-not-empty) {
                $cfg | merge { experimental: { clash_api: { external_controller: $clash_api } } }
            } else {
                $cfg
            }
            if ($output | is-not-empty) {
                $cfg | to json | save -f $output
            } else {
                $cfg | to json
            }
        }
    }
}

export def kdl-to-config [rule_bin_path, rule_prefix?] {
    let o = $in
    let rules = $o | where name == rules | kdl-to-rules
    let rule_set = scan-binary-ruleset $rule_bin_path
    | append ($o | where name == rule_set | kdl-to-ruleset)
    let rule_set = if ($rule_prefix | is-empty) {
        $rule_set
    } else {
        # 本地规则集重写为相对工作目录（-D）的路径，产物可移植；布局由调用方决定
        $rule_set | each {|r|
            if $r.type == local { $r | update path $"($rule_prefix)/($r.path | path basename)" } else { $r }
        }
    }
    let outbounds = $o | where name == outbounds | kdl-to-outbounds
    $o | where name == singbox | merge-config $rules $rule_set $outbounds
}

def new [rec] {
    { name: "", args: [], props: {}, children: [] } | merge $rec
}

export def outbounds-to-kdl [tag props={}] {
    $in
    | each {|x|
        let name = $x.type? | default "unknown"
        let children = $x
        | reject type tag
        | items {|k, v|
            let vt = $v | describe -d | get type
            let args = if $vt != record { [$v] } else { [] }
            match $vt {
                record => {
                    match $vt {
                        record => {
                            let c1 = $v | items {|k1,v1|
                                let vt1 = $v1 | describe -d | get type
                                match $vt1 {
                                  string | bool | number => { new {args: [$v1]} }
                                  list => { new {args: $v1} }
                                  record => { new {props: $v1} }
                                  nothing => { new {} }
                                  _ => { new {args: [$vt1 $"($v1)"]} }
                                }
                                | merge {name: $k1}
                            }
                            new {name: $k, children: $c1 }
                        }
                        _ => {
                            new {name: $k}
                        }
                    }
                }
                _ => {
                    new {name: $k, args: [$v]}
                }
            }
        }
        new {name: $name, args:[$x.tag], children: $children }
    }
    | new {
        name: outbounds
        args: [$tag]
        props: $props
        children: $in
    }
    | to kdl --format nodes
}

export def outbounds-item [] {
    $in | reduce -f {} {|z, a|
        if ($z.children? | is-not-empty) {
            let c = $z.children
            | reduce -f {} {|i,a|
                let l = $i.args? | default 0 | length
                let c1 = if $l > 1 {
                    $i.args
                } else if $l > 0 {
                    $i.args.0
                } else if ($i.props | is-not-empty) {
                    $i.props
                }
                $a | upsert $i.name $c1
            }
            $a | upsert $z.name $c
        } else {
            $a | upsert $z.name $z.args.0?
        }
    }
}

# sing-box 官方支持的全部 outbound 协议 (sing-box 1.13.x docs /configuration/outbound/)
# 用于从聚合节点(urltest/selector 等)中过滤出协议子节点；ssr 非 sing-box 原生，保留兼容
const SUPPORTED_PROTOCOL = [
    direct block
    http socks mixed
    shadowsocks shadowsocks2009 shadowsocks2022
    vmess vless trojan
    hysteria hysteria2 anytls
    wireguard ssh tuic shadowtls
    ssr
]

export def kdl-to-outbounds [] {
    $in | each {|x|
        let ob = $x.children | where name in $SUPPORTED_PROTOCOL
        let op = $x.children
        | where name not-in $SUPPORTED_PROTOCOL
        | reduce -f {} {|y,a| $a | upsert $y.name $y.args.0? }
        mut r = [
            {
                type: $x.props.type?
                tag: $x.args.0
                outbounds: ($ob | each { ($x.args.0)-($in | get args.0) })
                ...$op
            }
        ]
        for i in $ob {
            $r ++= [{
                type: $i.name
                tag: ($x.args.0)-($i.args.0)
                ...($i.children | outbounds-item)
            }]
        }
        $r
    }
    | flatten
}

export def kdl-to-rules [] {
    let x = $in
    mut r = []
    mut cur = []
    for i in ($x.children | flatten) {
        let n = $i.name
        let a = $i.args.0
        let p = $i.props
        if $n == $cur.0? and $a == $cur.1? {
            match $n {
                action if $p.method? == $cur.2.method? => {
                    $cur.2.protocol = $cur.2.protocol | append $p.protocol?
                }
                outbound => {
                    $cur.2.rule_set = $cur.2.rule_set | append $p.rule_set
                }
            }
        } else {
            if ($cur | is-not-empty) {
                $r = $r | append {$cur.0: $cur.1, ...$cur.2}
            }
            let p = $p
            | update rule_set? {|y| [$y.rule_set] }
            | update protocol? {|y| [$y.protocol] }
            $cur = [$n, $a, $p]
        }
    }
    # $cur is [] when there is no rules block (empty input); guard before indexing $cur.0
    if ($cur | is-not-empty) { $r | append {$cur.0: $cur.1, ...$cur.2} } else { $r }
}

export def merge-config [rules rule_set outbounds] {
    $in
    | reduce -f [] {|i,a| $a | append $i.children }
    | reduce -f {} {|i,a|
        match $i.name {
            log => {
                $a | merge {log: $i.props}
            }
            dns => {
                let c = $i.children
                | each {|x|
                    {
                        type: $x.name
                        ...$x.props
                    }
                }
                $a | merge {$i.name: {servers: $c}}
            }
            inbounds | outbounds => {
                let c = $i.children
                | each {|x|
                    {
                        type: $x.name
                        ...$x.props
                    }
                }
                $a | merge {$i.name: $c}
            }
            route => {
                mut c = {rules: $rules, rule_set: $rule_set}
                for x in $i.children {
                    match $x.name {
                        default_domain_resolver => {
                            $c = $c | upsert $x.name $x.props
                        }
                        _ => { $c = $c | upsert $x.name $x.args.0 }
                    }
                }
                $a | merge {$i.name: $c}
            }
            _ => {
                let c = $i.children
                | reduce -f {} {|x, a|
                    $a | insert $x.name $x.props
                }
                $a | merge {$i.name: $c}
            }
        }
    }
    | update outbounds {|x| $x.outbounds | append $outbounds }
}

export def kdl-to-ruleset [] {
    $in
    | group-by args.0
    | items {|k, v|
        { tag: $k, children: ($v.children | flatten) }
    }
    | each {|x|
        mut r = {
            ip_cidr: []
            domain_keyword: []
            domain_suffix: []
        }
        for i in $x.children {
            match $i.name {
                ip_cidr => { $r.ip_cidr ++= $i.args }
                domain_keyword => { $r.domain_keyword ++= $i.args }
                domain_suffix => { $r.domain_suffix ++= $i.args }
            }
        }
        {
            type: inline
            tag: $x.tag
            rules: [$r]
        }
    }
}

export def scan-binary-ruleset [path] {
    if ($path | is-empty) { return [] }
    glob ($path)/*.srs
    | each {|x|
        {
            type: local
            tag: $"srs-($x | path parse | get stem)"
            format: binary
            path: $x
        }
    }
}
