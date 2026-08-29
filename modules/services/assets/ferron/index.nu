#!/usr/bin/env -S nu --stdin

const utils = path self utils.nu
use $utils *

export def main [] {
    let n = $in
    send-file (path self README.md)
}
