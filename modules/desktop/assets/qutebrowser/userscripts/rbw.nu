#!/usr/bin/env nu

use qute.nu
export-env { use qute.nu }

def rbw-get [type:string] {
    let s = $in
    let act = match $type {
        password => 'get'
        code => 'code'
    }
    let r = rbw $act $s.2 $s.1 | complete
    if ($r.stdout | is-empty) {
        $r.stderr | log -t error
    } else {
        [$s.1 ($r.stdout | str trim)]
    }
}

def rbw-select [] {
    let u = qute get-url
    rbw search $u.host
}

def parse-uri [] {
    $in
    | each {
        let p = $in | split row '/'
        let p = if ($p | length) > 1 {
            [$p.0 $p.1]
        } else {
            ['' $p.0]
        }
        let i = $p.1 | split row '@'
        let i = if ($i | length) > 1 {
            [($i | range 0..<-1 | str join '@'), ($i | last)]
        } else {
            ['', $i.0]
        }
        [$p.0 ...$i]
    }
}

export def main [...args] {
    qute list-env
    let a = rbw-select
    | lines
    | qute select

    if ($a | is-empty) {
        return $env.QUTE_EXIT_CODE.SUCCESS
    }

    let a = $a
    | parse-uri
    | rbw-get password

    # $a | to json | log -t info

    $a.0 | qute fake-key-raw
    '<tab>' | qute fake-key
    $a.1 | qute fake-key-raw

    $env.QUTE_EXIT_CODE.SUCCESS
}
