#!/usr/bin/env -S nu --stdin

const utils = path self utils.nu
use $utils *

export def main [] {
    match ($env.REQUEST_METHOD | str lowercase) {
        post | put => {
            let i = $in | upload
            let prefix_len = $env.PREFIX_LEN? | default 1 | into int
            let parts = $env.PATH_INFO | path split | skip 1
            let segments = $parts | skip $prefix_len
            let hooks_root = [
                $env.DOCUMENT_ROOT
                ...($parts | slice ..<$prefix_len)
                ($env.HOOKS_PATH? | default '__hooks__')
            ] | path join

            mut hook_path = ''

            let paths = [ $segments ($segments | drop 1 | append '_') ]
            | append (1..($segments | length) | each {|i| $segments | drop $i | append '__'})


            for p in $paths {
                let candidate_path = $hooks_root | path join ...$p
                if ($candidate_path | path exists) {
                    $hook_path = $candidate_path
                    break
                }
            }

            content -s

            # print ($paths | to yaml)
            if ($hook_path | is-not-empty) {
                let workdir = mktemp -d
                cd $workdir
                let script = [$workdir run.nu] | path join
                $"(open -r $hook_path)\n\nexport def main [] { let o = $in | from json; file_uploaded $o }" | save -f $script
                $i
                | insert location {|x| $env.DOCUMENT_ROOT | path join ($x.filename | str trim -c '/')}
                | to json -r
                | nu --stdin $script
                cd ..
                rm -rf $workdir
            } else {
                $i | to json -r
            }
        }
        _ => {
            index
        }
    }
}

def index [] {
    let file = path-to-file
    send-file $file
}

def upload [] {
    let n = $in
    let dest = path-to-file
    let parent = $dest | path parse | get parent
    if not ($parent | path exists) {
        mkdir $parent
    }
    $n | save -f $dest
    let binary = ($n | describe -d).type == 'binary'
    let size = if $binary {
        $n | bytes length
    } else {
        $n | str length
    }
    {
        event: "file_uploaded",
        host: $env.HTTP_HOST
        binary: $binary
        size: $size
        filename: $env.PATH_INFO,
        timestamp: (date now | format date "%+")
    }
}
