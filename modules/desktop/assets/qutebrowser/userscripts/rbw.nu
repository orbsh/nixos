#!/usr/bin/env nu

use qute.nu
export-env { use qute.nu }

# ── CLI 封装 ────────────────────────────────────────────

# 列出所有条目
def rbw-list [] {
    rbw list | lines
}

# 按域名搜索
def rbw-search [host: string] {
    rbw search $host | lines
}

# 获取密码
def rbw-password [folder: string, name: string] {
    let r = rbw get $name $folder | complete
    if ($r.exit_code != 0) {
        $r.stderr | log -t error
        return null
    }
    $r.stdout | str trim
}

# 获取 TOTP
def rbw-totp [folder: string, name: string] {
    let r = rbw code $name $folder | complete
    if ($r.exit_code != 0) {
        $r.stderr | log -t error
        return null
    }
    $r.stdout | str trim
}

# ── 解析逻辑 ─────────────────────────────────────────────

# 解析 rbw 条目格式: folder/name@user → [folder, name, user]
def parse-entry [entry: string] {
    let p = $entry | split row '/'
    let p = if ($p | length) > 1 {
        [$p.0 ($p | range 1.. | str join '/')]
    } else {
        ['' $p.0]
    }
    let i = $p.1 | split row '@'
    let i = if ($i | length) > 1 {
        [($i | range 0..<-1 | str join '@') ($i | last)]
    } else {
        ['' $i.0]
    }
    [$p.0 $i.0 $i.1]
}

# ── 密码填入模式 ─────────────────────────────────────────

def fill-password [entry: string] {
    let parsed = parse-entry $entry
    let folder = $parsed.0
    let name = $parsed.1
    let user = $parsed.2

    let password = rbw-password $folder $name
    if ($password | is-empty) {
        '未获取到密码' | log -t error
        exit $env.QUTE_EXIT_CODE.FAILURE
    }

    # 注入: 用户名 <tab> 密码
    if ($user | is-not-empty) {
        $user | qute fake-key-raw
        '<tab>' | qute fake-key
    }
    $password | qute fake-key-raw

    $env.QUTE_EXIT_CODE.SUCCESS
}

# ── 菜单生成模式 ─────────────────────────────────────────

def select-menu [] {
    # 按当前 URL 搜索匹配条目
    let url = qute get-url
    let entries = rbw-search $url.host

    if ($entries | is-empty) {
        $"未找到 ($url.host) 的匹配条目" | log -t warning
        return $env.QUTE_EXIT_CODE.NO_PASS_CANDIDATES
    }

    # 构造 prompt-select 命令，选中后回调自身
    let script = $env.CURRENT_FILE
    let args = ($entries | each { |e|
        [$'spawn --userscript ($script) --fill "($e)"' $e]
    } | flatten)

    [
        'prompt-select'
        '-text'
        'Select Bitwarden Entry:'
        ...$args
    ] | str join ' ' | qute command
}

# ── 主入口 ───────────────────────────────────────────────

def main [
    --fill: string = ''   # --fill <entry>: 密码填入模式
] {
    qute list-env

    if ($fill | is-not-empty) {
        fill-password $fill
    } else {
        select-menu
    }
}
