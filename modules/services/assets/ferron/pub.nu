#!/usr/bin/env -S nu --stdin

const utils = path self utils.nu
use $utils *

export def main [] {
    let n = $in
    match ($env.REQUEST_METHOD | str lowercase) {
        get => {
            serve
        }
        _ => {
            status 403
        }
    }
}

def serve [] {
    let root = $env.PUB_ROOT? | default $env.DOCUMENT_ROOT
    let prefix_len = $env.PREFIX_LEN? | default 1 | into int
    let rel = $env.PATH_INFO
        | path split
        | skip 1
        | skip $prefix_len
        | path join
    send-file ($root | path join $rel)
}
