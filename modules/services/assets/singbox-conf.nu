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
    --output: string
] {
    match $action {
        outbounds-to-kdl => {
            $in | outbounds-to-kdl
        }
        kdl-to-config => {
            $in | kdl-to-config $rule_bin_path
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
            let cfg = $merged | kdl-to-config $rule_bin_path
            if ($output | is-not-empty) {
                $cfg | to json --raw | save -f $output
            } else {
                $cfg
            }
        }
    }
}

export def kdl-to-config [rule_bin_path] {
    let o = $in
    let rules = $o | where name == rules | kdl-to-rules
    let rule_set = scan-binary-ruleset $rule_bin_path
    | append ($o | where name == rule_set | kdl-to-ruleset)
    let outbounds = $o | where name == outbounds | kdl-to-outbounds
    $o | where name == singbox | merge-config $rules $rule_set $outbounds
}

def new [rec] {
    { name: "", args: [], props: {}, children: [] } | merge $rec
}

export def outbounds-to-kdl [] {
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
    | new {name: outbounds, children: $in}
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

const SUPPORTED_PROTOCOL = [trojan anytls hysteria2 vmess vless ssr]
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
    mut cur = {}
    for i in ($x.children | flatten | where name == rule | get props) {
        if ($i.action? | is-not-empty) and $i.action? == $cur.action? and $i.method? == $cur.method? {
            $cur.protocol = $cur.protocol? | append $i.protocol?
        } else if ($i.outbound? | is-not-empty) and $i.outbound? == $cur.outbound? {
            $cur.rule_set = $cur.rule_set? | append $i.rule_set?
        } else {
            if ($cur | is-not-empty) {
                $r = $r | append $cur
            }
            let i = $i
            | update rule_set? {|y| [$y.rule_set]}
            | update protocol? {|y| [$y.protocol] }
            $cur = $i
        }
    }
    $r | append $cur
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
            tag: $x.args.0
            rules: $r
        }
    }
}

export def scan-binary-ruleset [path] {
    if ($path | is-empty) { return }
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
