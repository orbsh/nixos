#!/usr/bin/env nu
# 上游清单工具 —— 手动维护版本的包：查最新 / 校验 hash / 下载镜像 / 改写 Nix 文件
#
#   nu scripts/upstream.nu check [name]     # release/doc：上游最新 tag vs 清单 current
#   nu scripts/upstream.nu audit [name]     # mirror：本地文件 hash vs Nix 文件里记录的值
#   nu scripts/upstream.nu hash <name>      # 打印本地文件的 hash（按清单的 hash 类型）
#   nu scripts/upstream.nu fetch <name>     # 按 upstream 下载到 dest（镜像缺文件时用）
#   nu scripts/upstream.nu bump <name> [--to V] [--write]
#                                          # release：查最新(或 --to)→ 算 hash → 改写 version/url/hash 行
#                                          # mirror ：用本地文件重算 hash（+ 换版本时改 url/file 名）
#   默认 dry-run，只有 --write 才落盘。

def here [] { $env.FILE_PWD? | default (pwd) }

# 仓库根解析：脚本可能以 store 副本形式被 updateScript 调用（自身目录里没有清单），
# 所以优先用 $env.UPSTREAM_REPO，其次从 cwd 向上找 scripts/upstream.yml，最后回退脚本自身目录。
def walk-up [d: string] {
  if ($d | path join 'scripts/upstream.yml' | path exists) { return $d }
  let up = $d | path dirname
  if $up == $d or ($up | is-empty) { return null }
  walk-up $up
}

def repo-root [] {
  let repo_env = $env.UPSTREAM_REPO? | default ''
  if $repo_env != '' { return $repo_env }
  let repo_cwd = walk-up (pwd)
  if $repo_cwd != null { return $repo_cwd }
  here | path dirname
}

def manifest [] { open ((repo-root) | path join 'scripts/upstream.yml') }

def proxy [] { manifest | get settings.proxy? | default null }

def curl-run [args: list<string>] {
  let p = proxy
  if $p == null { ^curl ...$args } else { ^curl --proxy $p ...$args }
}

def entry [name: string] {
  let e = manifest | get entries | get -o $name
  if $e == null { error make { msg: $"清单里没有条目：($name)" } }
  { name: $name } | merge $e
}

def dest-path [e: record] {
  let d = $e.dest | default null
  if $d == null { null } else {
    let base = $d | str replace --all --regex '^~' $env.HOME
    let f = $e.file | str replace --all --regex '\{v\}' ($e.current | default '' | into string)
    $base | path join $f
  }
}

def local-file [e: record] {
  let p = dest-path $e
  if $p == null or not ($p | path exists) { null } else { $p }
}

# ── hash 计算（三种约定）────────────────────────────────────
def hash-of [p: path, kind: string] {
  match $kind {
    "flat" => (^nix hash file --type sha256 --sri $p | str trim)
    "file" => (^nix hash path --type sha256 --sri $p | str trim)
    "tree" => (^nix hash convert --hash-algo sha256 --to sri (^nix-prefetch-url --unpack --type sha256 $"file://($p)" | str trim))
    _ => (error make { msg: $"未知 hash 类型：($kind)" })
  }
}

def hash-url [url: string] {
  # nix 的 https 取包走代理（同 flake.nix 的约定）
  let p = proxy
  let b32 = if $p == null { ^nix-prefetch-url --type sha256 $url } else {
    with-env { https_proxy: $p, http_proxy: $p } { ^nix-prefetch-url --type sha256 $url }
  } | str trim
  ^nix hash convert --hash-algo sha256 --to sri $b32 | str trim
}

# ── 站点文件里的记录值 ──────────────────────────────────────
def site-files [e: record] {
  if ($e | columns | any {|c| $c == "sites" }) {
    $e.sites | each {|s| $s | values | first }
  } else if ($e | columns | any {|c| $c == "site" }) {
    [ $e.site ]
  } else { [] }
}

def recorded-hash [file: string, context: string] {
  let txt = open ((repo-root) | path join $file) --raw
  let body = if ($context | is-empty) { $txt } else {
    let idx = $txt | str index-of $context
    if $idx < 0 { $txt } else { $txt | str substring $idx.. }
  }
  let m = $body | parse --regex '"?(?<h>sha256-[A-Za-z0-9+/=]+)"?' | get h? | default []
  if ($m | length) == 0 { null } else { $m | first }
}

# ── 命令 ────────────────────────────────────────────────────
def latest-tag [e: record] {
  if ($e.repo? | default null) == null { return null }
  # 默认看正式 release；prerelease: true 的条目（如 ferron 跑在 3.x beta/rc）取含预发布的最新
  let api = if ($e.prerelease? | default false) {
    $"https://api.github.com/repos/($e.repo)/releases?per_page=1"
  } else {
    $"https://api.github.com/repos/($e.repo)/releases/latest"
  }
  let out = curl-run [ "-fsSL" $api ]
  let parsed = $out | from json
  let tag = if $e.prerelease? == true { $parsed | get 0.tag_name } else { $parsed | get tag_name }
  # tag 模板 {v} → 版本；v{v} → 去掉前缀
  let prefix = $e.tag | split row "{v}" | first
  $tag | str replace --all --regex $"^($prefix | str replace --all --regex '\{v\}' '')" ""
}

def "main check" [name?: string] {
  let names = if $name == null { manifest | get entries | columns } else { [ $name ] }
  print "条目               当前          上游最新      状态"
  for n in $names {
    let e = entry $n
    if $e.kind == "mirror" and ($e.repo? | default null) == null { continue }
    if ($e.pinned-tag? | default false) {
      let note = "固定 tag：" + ($e.tag | into string)
      print $"($n | fill -w 18)($e.current | default '-' | fill -w 14)($note | fill -w 14)—"
      continue
    }
    let latest = try { latest-tag $e } catch { null }
    let cur = $e.current | default "-"
    let state = if $latest == null { "?" } else if $latest == $cur { "ok" } else { "可更新" }
    print $"($n | fill -w 18)($cur | fill -w 14)($latest | default '-' | fill -w 14)($state)"
  }
}

def "main audit" [name?: string] {
  let names = if $name == null { manifest | get entries | columns } else { [ $name ] }
  print "条目               本地文件 hash                                 记录值                                        状态"
  for n in $names {
    let e = entry $n
    if $e.kind != "mirror" { continue }
    let f = local-file $e
    if $f == null { print $"($n | fill -w 18)(缺本地文件)"; continue }
    let h = hash-of $f $e.hash
    let recs = site-files $e | each {|s| recorded-hash $s ($e.context? | default "") } | compact
    let state = if ($recs | any {|r| $r == $h }) { "ok" } else { "不一致" }
    print $"($n | fill -w 18) ($h | fill -w 46) ($recs | str join ',' | fill -w 46) ($state)"
  }
}

def "main hash" [name: string] {
  let e = entry $name
  let f = local-file $e
  if $f == null { error make { msg: $"本地文件不存在：($f)" } }
  hash-of $f $e.hash
}

def download [e: record, ver: string, force: bool] {
  let d = dest-path ($e | merge { current: $ver })
  if ($d | path exists) and (not $force) { print $"已存在，跳过：($d)"; return $d }
  mkdir ($d | path dirname)
  let url = $e.upstream | str replace --all --regex '\{v\}' $ver
  print $"下载：($url)"
  curl-run [ "-fL" "--create-dirs" "-o" $d $url ] | ignore
  print $"完成：($d)"
  $d
}

def "main fetch" [name: string, --force] {
  let e = entry $name
  if $e.kind != "mirror" { error make { msg: $"($name) 是 ($e.kind) 条目，没有要下载到 dest 的产物（release 由 Nix 的 fetchurl 取，doc 只有版本串），fetch 只用于 mirror" } }
  if ($e.upstream? | default null) == null { error make { msg: $"($name) 没配 upstream，无法下载" } }
  download $e ($e.current | default '' | into string) $force
}

# 清单里条目的 current 行改写成新版本（其余行不动）
def set-manifest-current [name: string, ver: string] {
  let f = (repo-root) | path join 'scripts/upstream.yml'
  let lines = open $f --raw | lines
  let start = $lines | enumerate | where {|x| $x.item | str starts-with $"  ($name):" } | get index? | default []
  if ($start | length) == 0 { print $"  清单里找不到 ($name) 条目，current 未改"; return }
  let s = $start | first
  let rest = $lines | skip ($s + 1)
  let stop = $rest | enumerate | where {|x| ($x.item | parse --regex '^  [A-Za-z0-9_-]+:$' | length) > 0 } | get index? | default []
  let e = if ($stop | length) == 0 { ($lines | length) - 1 } else { $s + ($stop | first) }
  let patched = $lines | enumerate | each {|x|
    if $x.index > $s and $x.index <= $e and ($x.item | str trim | str starts-with "current:") {
      let indent = $x.item | str replace --all --regex '[^ ].*$' ''
      let note = $x.item | parse --regex 'current:\s*(?:"[^"]*"|null)\s*(?<note>#.*)?$' | get note.0? | default ''
      if ($note | is-empty) { $"($indent)current: \"($ver)\"" } else { $"($indent)current: \"($ver)\" ($note)" }
    } else { $x.item }
  }
  $patched | str join (char nl) | save -f $f
  print $"  清单 current -> ($ver)"
}

def replace-line [file: path, old: string, new: string, context: string] {
  let txt = open $file --raw
  if ($context | is-empty) {
    if not ($txt | str contains $old) { return false }
    $txt | str replace --all $old $new | save -f $file
    return true
  }
  let lines = $txt | lines
  let ci = $lines | enumerate | where {|x| $x.item | str contains $context } | get index? | default []
  if ($ci | length) == 0 { return false }
  let start = $ci | first
  let tail = $lines | skip $start
  let hit = $tail | enumerate | where {|x| $x.item | str contains $old } | get index? | default []
  if ($hit | length) == 0 { return false }
  let at = $start + ($hit | first)
  let patched = $lines | enumerate | each {|x| if $x.index == $at { $new } else { $x.item } }
  $patched | str join (char nl) | save -f $file
  true
}

def "main bump" [name: string, --to: string, --write, --force] {
  let e = entry $name
  let kind = $e.kind
  let sites = site-files $e
  if ($sites | is-empty) { error make { msg: $"($name) 没配 site" } }

  if $kind == "release" {
    let ver = $to | default (latest-tag $e)
    if $ver == null { error make { msg: "取不到上游最新版本，用 --to 指定" } }
    if $ver == $e.current { print $"($name) 已是最新（($ver)）"; return }
    let url = $e.url | str replace --all --regex '\{v\}' $ver
    print $"($name)：($e.current) -> ($ver)"
    print $"  url : ($url)"
    let h = hash-url $url
    print $"  hash: ($h)"
    if not $write { print "  (dry-run，未落盘)"; return }
    mut ok = true
    for s in $sites {
      let f = (repo-root) | path join $s
      let oldVerline = $e.version-line | str replace --all --regex '\{v\}' $e.current
      let newVerline = $e.version-line | str replace --all --regex '\{v\}' $ver
      if (replace-line $f $oldVerline $newVerline ($e.context? | default "")) {
        print $"  已更新 ($s) 版本行：($oldVerline) -> ($newVerline)"
      } else {
        print $"  警告：($s) 里没找到 ($oldVerline)，版本行未改写（核对 version-line 模板与 current）"
        $ok = false
      }
      if ($e.url-line? | default null) != null {
        replace-line $f ($e.url-line | str replace --all --regex '\{u\}' ($e.url | str replace --all --regex '\{v\}' $e.current)) ($e.url-line | str replace --all --regex '\{u\}' $url) ($e.context? | default "") | ignore
      }
      let oldh = recorded-hash $s ($e.context? | default "")
      if $oldh != null {
        replace-line $f ($e.hash-line | str replace --all --regex '\{h\}' $oldh) ($e.hash-line | str replace --all --regex '\{h\}' $h) ($e.context? | default "") | ignore
      }
    }
    if $ok {
      print $"  已写入：($sites | str join ', ')"
      set-manifest-current $name $ver
    } else {
      print "  有站点文件的版本行未改写，清单 current 保持不动（避免台账与实际版本脱节）"
    }
    return
  }

  if $kind == "doc" {
    # doc 条目：版本串只出现在站点文件的脚本文本里（无产物可下载），bump = 改写那一行
    if ($e.version-line? | default null) == null { error make { msg: $"($name) 没配 version-line" } }
    let ver = $to | default (latest-tag $e)
    if $ver == null { error make { msg: "取不到上游最新版本，用 --to 指定" } }
    if $ver == $e.current { print $"($name) 已是最新（($ver)）"; return }
    let oldVerline = $e.version-line | str replace --all --regex '\{v\}' ($e.current | default '' | into string)
    let newVerline = $e.version-line | str replace --all --regex '\{v\}' $ver
    print $"($name)：($e.current) -> ($ver)"
    print $"  站点行: ($oldVerline) -> ($newVerline)"
    if not $write { print "  (dry-run，未落盘)"; return }
    mut ok = true
    for s in $sites {
      let f = (repo-root) | path join $s
      if (replace-line $f $oldVerline $newVerline ($e.context? | default "")) {
        print $"  已更新 ($s)：($oldVerline) -> ($newVerline)"
      } else {
        print $"  警告：($s) 里没找到 ($oldVerline)，版本行未改写（核对 version-line 模板与 current）"
        $ok = false
      }
    }
    if $ok {
      set-manifest-current $name $ver
    } else {
      print "  站点文件的版本行未改写，清单 current 保持不动（避免台账与实际版本脱节）"
    }
    return
  }

  if $kind == "mirror" {
    let oldVer = $e.current | default '' | into string
    let ver = $to | default $oldVer
    if $ver == '' { error make { msg: $"($name) 清单没有 current，按需用 --to 指定版本" } }
    # 版本变了（或 --force）先取新版文件；文件名不含 {v} 的条目必须 --force 覆盖
    if $ver != $oldVer or $force {
      if ($e.upstream? | default null) == null { error make { msg: $"($name) 没配 upstream，无法下载；手工放好文件后再 bump" } }
      if not $write { print $"将下载新版本 ($ver)（dry-run 不下载）" } else {
        download ($e | merge { current: $ver }) $ver ($ver == $oldVer or $force) | ignore
      }
    }
    let f = dest-path ($e | merge { current: $ver })
    if $f == null or not ($f | path exists) { error make { msg: $"本地文件不存在：($f)" } }
    let h = hash-of $f $e.hash
    let newUrl = if ($e.url? | default null) == null { null } else { $e.url | str replace --all --regex '\{v\}' $ver }
    print $"($name)：($oldVer) -> ($ver)"
    print $"  本地文件: ($f)"
    print $"  新 hash : ($h)（kind=($e.hash)）"
    if ($newUrl != null) and $newUrl != ($e.url | str replace --all --regex '\{v\}' $oldVer) { print $"  新 url  : ($newUrl)" }
    if not $write { print "  (dry-run，未落盘)"; return }
    for s in $sites {
      let file = (repo-root) | path join $s
      let oldh = recorded-hash $s ($e.context? | default "")
      if $oldh != null and $oldh != $h {
        replace-line $file ($e.hash-line | str replace --all --regex '\{h\}' $oldh) ($e.hash-line | str replace --all --regex '\{h\}' $h) ($e.context? | default "") | ignore
        print $"  已更新 ($s) hash：($oldh) -> ($h)"
      } else { print $"  ($s) hash 已是该值" }
      if ($e.url-line? | default null) != null and $newUrl != null {
        let oldUrl = $e.url | str replace --all --regex '\{v\}' $oldVer
        if $oldUrl != $newUrl {
          replace-line $file ($e.url-line | str replace --all --regex '\{u\}' $oldUrl) ($e.url-line | str replace --all --regex '\{u\}' $newUrl) ($e.context? | default "") | ignore
          print $"  已更新 ($s) url：($oldUrl) -> ($newUrl)"
        }
      }
    }
    set-manifest-current $name $ver
  }
}

def main [] {
  print "用法：nu scripts/upstream.nu <check|audit|hash|fetch|bump> [name] [--to V] [--write]"
}