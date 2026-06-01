def cmpl-hosts [] {
    nix flake show --json | from json | get nixosConfigurations | columns
}

export def switch [profile: string@cmpl-hosts = 'workstations_orbit'] {
    $env.NIXOS_LABEL = (git log -1 --pretty=format:"%s" | sed 's/ /_/g')
    sudo -E nixos-rebuild switch --flake $".#($profile)"
}

export def build [profile: string@cmpl-hosts = 'workstations_orbit'] {
    nh os build $".#($profile)"    }

export def update [] {
    nh flake update
}

export def check [] {
    sudo nix flake check
}

export def add-file [file: path] {
    nix store add-file $file
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

export def install [
    host: string@cmpl-hosts = 'portable'
    --root: path = /mnt
    --no-root-password
] {
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
    if $no_root_password { $args ++= [--no-root-password] }
    sudo (which nixos-install).path.0 ...$args
}

export def rebuild [
    host: string@cmpl-hosts = 'portable'
    --root: path = /mnt
] {
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
}
