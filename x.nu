const ROOT = path self .

def cmpl-hosts [] {
    cd $ROOT
    nix flake show --json | from json | get nixosConfigurations | columns
}

export def switch [host: string@cmpl-hosts = 'workstations_orbit'] {
    cd $ROOT
    $env.NIXOS_LABEL = (git log -1 --pretty=format:"%s" | sed 's/ /_/g')
    sudo -E nixos-rebuild switch --flake $".#($host)"
}

export def build [
    host: string@cmpl-hosts = 'workstations_orbit'
    --harmonia: list<string>
] {
    mut args = []
    if ($harmonia | is-not-empty) {
        $args ++= [--option extra-substituters ($harmonia | str join ' ')]
    }
    nh os build $"($ROOT)#($host)" ...$args
}

export def update [] {
    cd $ROOT
    sudo nix flake update
}

export def check [] {
    cd $ROOT
    sudo nix flake check
}

export module mount {
    export def btrfs [
        --root(-r): string = "/dev/disk/by-uuid/3f9631a2-51ab-448a-9ac2-3b475fde7458"
        --boot(-b): string = "/dev/disk/by-uuid/B2EB-B6FC"
    ] {
        sudo mount -o compress=zstd,subvol=@ $root /mnt
        sudo mount $boot /mnt/boot
        sudo mount -o compress=zstd,subvol=@home $root /mnt/home
        sudo mount -o compress=zstd,subvol=@var,noatime $root /mnt/var
        sudo mount -o compress=zstd,subvol=@swap,noatime $root /mnt/swap
    }
}

export def mount [
    file: path
    --create
] {
    if $create {
        if ([no, yes] | input list '⚠️ WARNING: This will FORMAT the disk and ERASE ALL DATA. Continue? ') == 'yes' {
            sudo disko --mode disko $file
        }
    } else {
        sudo disko --mode mount $file
    }
}

export def install [
    host: string@cmpl-hosts = 'portable'
    --root: path = /mnt
    --set-root-password
] {
    cd $ROOT
    mut args = [
        --root $root --flake $".#($host)"
        --option substituters
        ([
            file:///nix/store
            https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store
            https://mirrors.ustc.edu.cn/nix-channels/store
            https://cache.nixos.org
        ] | str join ' ')
        --option trusted-public-keys "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ]
    if not $set_root_password { $args ++= [--no-root-password] }
    sudo (which nixos-install).path.0 ...$args
}

export def rebuild [
    host: string@cmpl-hosts = 'portable'
    --root: path = /mnt
] {
    cd $ROOT
    sudo (which nixos-enter).0.path ...[
        --root $root
        --
        /nix/var/nix/profiles/system/sw/bin/nixos-rebuild switch
        --flake ($env.PWD)#($host)
    ]
}

export def generate [
    --root: path = /mnt
] {
    sudo (which nixos-generate-config).path.0 --root $root
}

export def enter [
    --root: path = /mnt
] {
    sudo (which nixos-enter).path.0 --root $root
}

export module utils {
    export def "fetch-sri" [url: string] {
        ^curl -sL $url
        | hash sha256
        | decode hex
        | encode base64
        | $"sha256-($in)"
    }

    export def sha256 [file: path] {
        cat $file | hash sha256 | decode hex | encode base64
    }

    export def add-file [file: path] {
        let h = nix store add-file $file
        let p = nix hash path $h
        $'url = "file://($h)";(char newline)narHash = "($p)";'
    }
}

export def deployment [
    host: string@cmpl-hosts
    ssh
    --off-line
    --kexec: path = '~/pub/Application/Linux/nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz'
] {
    mut args = [
        --kexec $kexec
        --flake ($env.PWD)#($host) $ssh
    ]
    if $off_line {
        $args ++= [
            --no-substitute-on-destination
            --no-use-machine-substituters
        ]
    }
    nix run github:nix-community/nixos-anywhere -- ...$args

}
