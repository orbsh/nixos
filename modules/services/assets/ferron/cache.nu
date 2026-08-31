#!/usr/bin/env -S nu --stdin

const utils = path self utils.nu
use $utils *

# cache.nu: 前向缓存网关
#   URL 形态:  box.d/cache/<name>      (只有一级, name 是文件名)
#   逻辑:      文件在 CACHE_ROOT 存在 → 直接 send-file
#              不存在 → 读 CACHE_ROOT/index.yml 取 <name>: [urls]
#                       → 顺序 curl 下载(先成功者胜) → 存 CACHE_ROOT
#   环境变量:  CACHE_ROOT  (缓存目录, 默认 DOCUMENT_ROOT)
#
# index.yml 样例:
#   jcode-linux-x86_64.tar.gz:
#     - https://github.com/1jehuang/jcode/releases/download/xxx.tar.gz

export def main [] {
    let n = $in
    match ($env.REQUEST_METHOD | str lowercase) {
        get => { serve }
        _ => { status 403 }
    }
}

def serve [] {
    let root = $env.CACHE_ROOT? | default $env.DOCUMENT_ROOT
    # `/cache/<name>`: name = PATH_INFO 最后一段 (rewrite ^/cache/(.*) 到 /cache/$1)
    let name = $env.PATH_INFO | path split | last
    if ($name | is-empty) {
        status 404
        return
    }

    let file = $root | path join $name

    # 1. 缓存命中 → 直接返回
    if ($file | path exists) {
        send-file $file
        return
    }

    # 2. 缓存未命中 → 查 index.yml 获取下载源
    let index = $root | path join index.yml
    if not ($index | path exists) {
        status 404
        return
    }

    # open(不带 -r) 返回结构化 record; get $name 用字符串 key, 句号不会被当嵌套路径
    let urls = try {
        open $index | get $name
    } catch { null }
    if ($urls | is-empty) {
        status 404
        return
    }

    # 3. 顺序下载：先成功的那个写入缓存并返回
    mkdir $root
    let tmp = mktemp
    mut done = false
    for url in $urls {
        # complete 捕获外部命令(裸 curl 失败会终止 for 循环), 不传播非零退出
        let r = curl -fsSL --max-time 600 -o $tmp $url | complete
        let sz = try { ls $tmp | first | get size | into int } catch { 0 }
        # 成功 = 退出 0 且文件非空 (不盲目依赖 exit_code, 文件存在是最终判据)
        let ok = $r.exit_code == 0 and $sz > 0
        if $ok {
            mv -f $tmp $file
            $done = true
            break
        }
        # 失败清理临时文件, 试下一个源
        rm -f $tmp
    }

    if $done {
        send-file $file
    } else {
        status 404
    }
}