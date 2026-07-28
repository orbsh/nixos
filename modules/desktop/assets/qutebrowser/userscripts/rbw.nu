#!/usr/bin/env nu

use qute.nu
export-env { use qute.nu }

# ── CLI 封装 ────────────────────────────────────────────

# 按域名搜索，返回 tab 分隔的 name<TAB>user<TAB>folder
def rbw-search [host: string] {
    rbw search $host --fields name,user,folder | lines
}

# 获取密码
def rbw-password [name: string, user: string] {
    let r = if ($user | is-empty) {
        rbw get $name | complete
    } else {
        rbw get $name $user | complete
    }
    if ($r.exit_code != 0) {
        $r.stderr | qute log -t error
        return null
    }
    $r.stdout | str trim
}

# 获取 TOTP
def rbw-totp [name: string, user: string] {
    let r = if ($user | is-empty) {
        rbw code $name | complete
    } else {
        rbw code $name $user | complete
    }
    if ($r.exit_code != 0) {
        $r.stderr | qute log -t error
        return null
    }
    $r.stdout | str trim
}

# ── 解析逻辑 ─────────────────────────────────────────────

# 解析 walker 选中的行: name<TAB>user<TAB>folder
def parse-entry [entry: string] {
    let parts = ($entry | split row "\t")
    let name = $parts.0
    let user = if ($parts | length) > 1 { $parts.1 } else { '' }
    { name: $name, user: $user }
}

# ── 密码填入模式 ─────────────────────────────────────────

def fill-password [entry: string] {
    let parsed = parse-entry $entry

    let password = rbw-password $parsed.name $parsed.user
    if ($password | is-empty) {
        '未获取到密码' | qute log -t error
        exit $env.QUTE_EXIT_CODE.FAILURE
    }

    # 注入: 用户名 <tab> 密码
    if ($parsed.user | is-not-empty) {
        $parsed.user | qute insert-text
        '<Tab>' | qute fake-key
    }
    $password | qute insert-text

    $env.QUTE_EXIT_CODE.SUCCESS
}

# ── 菜单生成模式 ─────────────────────────────────────────

def select-menu [] {
    # 按当前 URL 搜索匹配条目
    let url = qute get-url
    let entries = rbw-search $url.host

    if ($entries | is-empty) {
        $"未找到 ($url.host) 的匹配条目" | qute log -t warning
        return $env.QUTE_EXIT_CODE.NO_PASS_CANDIDATES
    }

    # 使用 walker 过滤选择，选中后直接填充（单进程）
    let selected = ($entries | qute select | str trim)

    if ($selected | is-empty) {
        '用户取消选择' | qute log
        return $env.QUTE_EXIT_CODE.SUCCESS
    }

    fill-password $selected
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
