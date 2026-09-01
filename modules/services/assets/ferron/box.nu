#!/usr/bin/env -S nu --stdin

const utils = path self utils.nu
use $utils *

# box.nu: 统一数据网关 (读 + 上传 + 列目录) + token 角色鉴权
#   目录分割安全模型 (无目录内部过滤):
#     DATA_ROOT (data/)  - upload 角色读写; '' (无有效 token) 只读
#     HOOKS_ROOT (hooks/) - setup 角色读写 (上传 hook 脚本)
#     ACL_ROOT  (acl/)    - admin 角色读写 (含 index.yml)
#   URL 形态: box.d/box/<rel>    rel 相对当前 token 的角色根
#   鉴权: 请求头 `box-token: <token>` -> ACL_ROOT/index.yml 中该 token 的角色
#        role: admin|setup|upload|'' (''=无有效 token, 匿名只读 data)
#   读取无需 token (目录不同而已); 写入要求 role 非空
#   hook 寻址 (核心特性, 保留): 上传到 data/<rel> 时,
#        在 HOOKS_ROOT/<rel> 下解析 run.nu 并执行
#   启动引导: ACL_ROOT/index.yml 缺失时首请求生成随机 admin token
#   安全: 路径穿越防护 (目标必须位于自己的角色根内)
#   数据流: token 只解析一次 (token-role), 根目录存在由启动/部署保证, 不逐请求查

export def main [] {
    # 第一行捕获 stdin (若先调用其他函数会抢占 $in)
    let body = $in
    ensure-bootstrap
    match ($env.REQUEST_METHOD | str lowercase) {
        get         => { serve }
        post | put  => { $body | upload }
        _           => { status 403 }
    }
}

# ── 路径解析 ─────────────────────────────────────────────
# PATH_INFO = /box/<rel> (rewrite 后), 去掉 'box' 前缀得操作相对路径
def rel-segments [] {
    $env.PATH_INFO
    | path split
    | skip 1
    | skip ($env.PREFIX_LEN? | default 1 | into int)
}
def rel [] { rel-segments | path join }

# 当前 token 的角色: admin|setup|upload|'' (''=无有效 token = 匿名)
# 空串作为 index.yml 的 record key 合法 (不存在 → get -o 给空 → default '')
def token-role [] {
    open (acl-file) | get -o ($env.HTTP_BOX_TOKEN? | default '') | default ''
}

# role -> 操作根 (纯映射, 无副作用; '' → DATA_ROOT 匿名只读)
def role-root-of [role] {
    match $role {
        admin  => { $env.ACL_ROOT? | default '' }
        setup  => { $env.HOOKS_ROOT? | default '' }
        _      => { $env.DATA_ROOT? | default '' }   # ''(匿名) 与 upload 都落 data
    }
}

# 逻辑路径不逃逸根 (不解析 symlink, 只规范化 ..)
def inside-root [path root] {
    let p = $path | path expand --no-symlink
    let r = $root | path expand --no-symlink
    $p | str starts-with $r
}

# ── ACL ──────────────────────────────────────────────────
def acl-file [] { ($env.ACL_ROOT? | default '') | path join 'index.yml' }
def data-root [] { $env.DATA_ROOT? | default '' }
def hooks-root [] { $env.HOOKS_ROOT? | default '' }

def ensure-bootstrap [] {
    let f = acl-file
    if ($f | path exists) { return }
    mkdir ($f | path dirname | path expand --no-symlink)
    {
      (random chars --length 24): admin
      (random chars --length 24): setup
      (random chars --length 24): upload
    }
    | to yaml
    | tee { save -f $f }
    | print -e $"(char nl)Generated acl/index.yml: ($in)"
}

# ── GET: 读 + 列目录 (无目录内过滤; 无需 token, 仅目录不同) ─
def serve [] {
    let root = role-root-of (token-role)
    let path = $root | path join (rel)
    if not (inside-root $path $root) { status 403; return }

    match ($path | path type) {
        file => { send-file $path }
        dir  => { list-dir $path }
        _    => { status 404 }
    }
}

def list-dir [dir] {
    content -j
    # 防线前移: cd 进 root 再 ls, name 从源头就是相对路径, 不在输出端事后换算
    cd $dir
    ls
    | select name type size modified
    | to json -r
}

# ── POST/PUT: 上传 (仅有效 token, role 非空) ──────────────
# 命中 hook 时 hook 输出作为响应 (SSE); 否则返回 event JSON
def upload [] {
    let n = $in
    let role = token-role
    if ($role | is-empty) { status 403; return }   # ''=无有效 token, 不可写

    let root = role-root-of $role
    let dest = $root | path join (rel)
    if not (inside-root $dest $root) { status 403; return }

    let parent = $dest | path parse | get parent
    if not ($parent | path exists) { mkdir $parent }
    $n | save -f $dest

    let event = {
        event: "file_uploaded",
        host: $env.HTTP_HOST
        binary: (($n | describe -d).type == 'binary')
        size: (if (($n | describe -d).type == 'binary') { $n | bytes length } else { $n | str length })
        filename: (rel)
        timestamp: (date now | format date "%+")
    }

    # hook 寻址: 仅 upload 传 data 时, 查 HOOKS_ROOT/<rel> 下 run.nu
    let hit = if ($role == 'upload') { run-hook-if-any $event } else { false }
    if not $hit {
        content -j
        $event | upsert location {|e| (rel) } | to json -r
    }
}

# 上传 data 命中 hook 时执行: 在 HOOKS_ROOT/<rel> 下解析 hook 脚本
def run-hook-if-any [event] {
    let segs = rel-segments
    let hooks_root = hooks-root

    mut hook_path = ''
    let paths = [$segs ($segs | drop 1 | append '_')]
        | append (1..($segs | length) | each {|i| $segs | drop $i | append '__'})

    for p in $paths {
        let candidate = $hooks_root | path join ...$p
        if ($candidate | path exists) { $hook_path = $candidate; break }
    }

    if ($hook_path | is-empty) { return false }

    content -s
    let workdir = mktemp -d
    cd $workdir
    let script = [$workdir run.nu] | path join
    $"(open -r $hook_path)\n\nexport def main [] { let o = $in | from json; file_uploaded $o }" | save -f $script
    $event
    | insert location {|e| (rel) }
    | to json -r
    | nu --stdin $script
    cd ..
    rm -rf $workdir
    return true
}