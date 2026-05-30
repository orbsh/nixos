export module workstation {
    export def rebuild [--nom(-n)] {
        if $nom {
            sudo nixos-rebuild switch --flake .#workstation --impure e+o>| nom
        } else {
            sudo nixos-rebuild switch --flake .#workstation --impure
        }
    }

    export def update [] {
        sudo nix flake update
    }
}

export module portable {
    export def mount-btrfs [
        --root(-r): string = "/dev/disk/by-uuid/3f9631a2-51ab-448a-9ac2-3b475fde7458"
        --boot(-b): string = "/dev/disk/by-uuid/B2EB-B6FC"
    ] {
        sudo mount -o compress=zstd,subvol=@ $root /mnt
        sudo mount $boot /mnt/boot
        sudo mount -o compress=zstd,subvol=@home $root /mnt/home
        sudo mount -o compress=zstd,subvol=@var,noatime $root /mnt/var
        sudo mount -o compress=zstd,subvol=@swap,noatime $root /mnt/swap
    }

    export def install [
        host: string = 'portable'
    ] {
        sudo (which nixos-install).path.0 ...[
            --root /mnt --flake $".#($host)"
            --option substituters
            ([
                file:///nix/store
                https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store
                https://mirrors.ustc.edu.cn/nix-channels/store
                https://cache.nixos.org
            ] | str join ' ')
            --option trusted-public-keys "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        ]
    }

    export def rebuild [
        host: string = 'portable'
    ] {
        sudo (which nixos-enter).0.path ...[
          --root /mnt
          --
          /nix/var/nix/profiles/system/sw/bin/nixos-rebuild switch
          --flake /home/master/nixos#($host)
        ]
    }

    export def generate [

    ] {
        sudo (which nixos-generate-config).path.0 --root /mnt
    }

    export def enter [] {
        sudo (which nixos-enter).path.0 --root /mnt
    }

    const ROOT = path self
    export def switch [
        host: string = 'portable'
        config: path = $ROOT
    ] {
        sudo nixos-install --root /mnt --no-root-password --flake $"($config)#($host)"
    }
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
