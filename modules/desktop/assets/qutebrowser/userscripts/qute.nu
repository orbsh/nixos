export def log [-t: string] {
    let msg = $in
    for l in ($msg | lines) {
        if ($t | is-empty) {
            $"($l)\n" | save -a $env.QUTE_LOG_FILE
        } else {
            let l = $l | str replace -a '"' '\"'
            $"message-($t) \"($l)\"\n" | save -a $env.QUTE_FIFO
        }
    }
}

export def command [] {
    $"($in)" | save -a $env.QUTE_FIFO
}

export def jseval [] {
    let j = $in
    | lines
    | each {|x|
        let x = $x | str trim
        if ($x | str starts-with '//') {
            ''
        } else {
            $x
        }
    }
    | str join ' '
    $"jseval ($j)" | save -a $env.QUTE_FIFO
}

export def jsesc [x] {
    # $x | sed "s,[\\\\'\"\/],\\\\&,g"
    $x | str replace -a -r "([\/\\\\'\"])+?" "\\${1}"
}

export def fake-key-raw [] {
    let text = $in
    # Escape all characters by default, space, '<' and '>' requires special handling
    let special_escapes = {
        ' ': '" "',
        '<': '<less>',
        '>': '<greater>',
    }
    mut r = []
    for i in 0..<($text | str length) {
        let i = $text | str substring $i..$i
        let i = if $i in $special_escapes {
            $special_escapes | get $i
        } else {
            $'\($i)'
        }
        $r ++= [$i]
    }
    let r =  $r | str join ''
    $'fake-key ($r)' | command
}

export def fake-key [] {
    $'fake-key ($in)' | command
}


export def insert-text [] {
    let r = $in | str replace -a '"' '\"'
    $'insert-text "($r)"'
}

export def select [] {
    let t = $in
    match $env.QUTE_SELECTOR {
        fuzzel => {
            $t  | str join "\n" | fuzzel --dmenu
        }
        rofi => {
            $t | rofi -dmenu -i
        }
    }
}

export def get-url [] {
    $env.QUTE_URL | url parse
}

export def list-env [] {
    for e in ($env | transpose k v) {
        if ($e.k | str starts-with 'QUTE_') {
            $"($e.k)=($e.v)" | log
        }
    }
}

export def selected-text [] {
    $env.QUTE_SELECTED_TEXT
}

export def open-tab [name] {
    let t = $in
    let d = [$env.QUTE_DATA_DIR open-tab] | path join
    let f = [$d $name] | path join
    if not ($d | path exists) { mkdir $d }
    $t | save -f $f
    $"open -t ($f)" | save -a $env.QUTE_FIFO
}

export def to-html [title] {
    let body = $in | lines | each {|x| $"<p>($x)</p>"}
    let head = [
        "<head>"
        "<style>"
        ".root{display:flex;flex-direction:column;flex: 1 1 auto;align-items:center;}"
        ".main{max-width:800px;display:flex;flex-direction:column;flex: 1 1 auto;align-items:stretch}"
        ".main>p{margin:0.3em 0;}"
        "</style>"
        "</head>"
        "<body>"
        "<div class=\"root\">"
        $"<h3>($title)</h3>"
        "<div class=\"main\">"
    ]
    let tail = [
        '</div>'
        '</div>'
        "</body>"
    ]
    [$head $body $tail] | flatten | str join (char newline)
}

export-env {
    $env.QUTE_EXIT_CODE = {
        SUCCESS: 0
        FAILURE: 1
        # 1 is automatically used if Python throws an exception
        NO_PASS_CANDIDATES: 2
        COULD_NOT_MATCH_USERNAME: 3
        COULD_NOT_MATCH_PASSWORD: 4
    }

    $env.QUTE_LOG_FILE = [$env.QUTE_DATA_DIR out] | path join

    for c in [fuzzel rofi] {
        if (which $c | is-not-empty) {
            $env.QUTE_SELECTOR = $c
            break
        }
    }
}
