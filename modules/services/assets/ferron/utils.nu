# Ferron Style Guide
#
# Style
# - Pipe first: use `| let x` tail binding, not `let x = (...)`
# - Variable reuse: compute once, use multiple times
#
# Refactor
# - Inline functions: helpers used by a single caller get merged into the caller

export def content [
  --json(-j)
  --plain(-p)
  --html(-h)
  --stream(-s)
  --length(-l): int
  --no-newline(-n)
] {
    mut hs = []
    if $json {
        $hs ++= ["Content-Type: application/json; charset=utf-8"]
    } else if $plain {
        $hs ++= ["Content-Type: text/plain"]
    } else if $stream {
      $hs ++= [
        "Content-Type: text/event-stream"
        "Cache-Control: no-cache"
        "X-Accel-Buffering: no"
      ]
    } else if $html {
        $hs ++= ["Content-Type: text/html; charset=utf-8"]
    } else {
        $hs ++= ["Content-Type: application/octet-stream"]
    }
    if ($length | is-not-empty) {
        $hs ++= [$"Content-Length: ($length)"]
    }
    if not $no_newline {
        $hs ++= ['']
    }

    $hs
    | str join (char newline)
    | print $in
}

export def status [code] {
    match $code {
        401 => {
            print "Status: 401 Unauthorized\n"
        }
        403 => {
            print "Status: 403 Forbidden\n"
        }
        404 => {
            print "Status: 404 Not Found\n"
        }
    }
}

export def is-binary-file []: binary -> bool {
    $in | first 512 | bytes index-of 0x[00] | $in >= 0
}

export def path-to-file [] {
    $env.DOCUMENT_ROOT | path join ($env.PATH_INFO | str trim -c '/')
}

export def send-file [file] {
    match ($file | path type) {
        file => {
            let is_bin = open -r $file | into binary | is-binary-file
            let sz = ls $file | first | get size | into int
            if $is_bin {
                content --length $sz
                cat $file
            } else {
                content -p --length $sz
                open -r $file
            }
        }
        dir => {
            cd $file
            content -j
            ls | to json -r
        }
        _ => {
            status 404
        }
    }
}

export def envs [] {
    $env
    | reject PROMPT_COMMAND ENV_CONVERSIONS PROMPT_COMMAND PROMPT_COMMAND_RIGHT config
}

export def json [...acts] {
    print "Content-Type: application/json\n"
    for a in $acts {
        let x = do $a
        if ($x | is-not-empty) {
            return ($x | to json -r)
        }
    }
}

export def route [
    pattern
    act
    --method(-m): string
] {
    if ($method | is-not-empty) {
        if ($env.REQUEST_METHOD | str lowercase) != ($method | str lowercase) {
            return
        }
    }
    let d = $env.PATH_INFO | parse -r $pattern
    if ($d | is-not-empty) {
        do $act ($d | first)
    }
}
