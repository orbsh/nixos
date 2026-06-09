const ROOT = path self .

def cmpl-hosts [] {
    cd $ROOT
    nix flake show --json | from json | get nixosConfigurations | columns
}

export def switch [
    host: string@cmpl-hosts = 'workstations_orbit'
    --remote: string
] {
    cd $ROOT
    $env.NIXOS_LABEL = (git log -1 --pretty=format:"%s" | sed 's/ /_/g')
    mut args = [
        switch
        --flake $".#($host)"
    ]
    if ($remote | is-not-empty) {
        # 远程：本机只做评估+构建，不需要 root；SSH 以当前用户运行，直接读 ~/.ssh/config
        $args ++= [--target-host $remote --use-remote-sudo]
        nixos-rebuild ...$args
    } else {
        # 本机：激活需要 root
        sudo -E nixos-rebuild ...$args
    }
}

export def build [
    host: string@cmpl-hosts = 'workstations_orbit'
    --harmonia: list<string>
] {
    mut args = []
    if ($harmonia | is-not-empty) {
        $args ++= [-- --option extra-substituters ($harmonia | str join ' ')]
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

export def iso-build [] {
    nix build .#iso.config.system.build.isoImage
}

export module qemu {
    def cmpl-iso [] {
        cd ($ROOT)/result/iso
        ls *.iso | get name
    }

    # OVMF UEFI 固件路径
    const OVMF_CODE = "/run/libvirt/nix-ovmf/edk2-x86_64-code.fd"
    const OVMF_VARS_SRC = "/run/libvirt/nix-ovmf/edk2-i386-vars.fd"
    const OVMF_VARS = "/home/master/.qemu/OVMF_VARS.fd"

    export def run [
        --iso: string@cmpl-iso
        --cow: path = "/home/master/.qemu/nixos.qcow2"
    ] {
        # 1. 公共基础配置（只放通用的硬件和网络参数）
        mut args = [
            -monitor stdio
            -enable-kvm
            -m 4G
            -smp 4
            -cpu host
            -vga virtio
            -net "nic,model=virtio"
            -net "user,hostfwd=tcp::2266-:2222"
            -device virtio-balloon-pci
            -display "sdl,gl=on"
            -device qemu-xhci
            -device usb-tablet
        ]

        # 2. 核心分流：有 ISO 时用你测试成功的纯命令，无 ISO 时加上 UEFI 固件进硬盘
        if ($iso | is-not-empty) {
            # 【有 ISO 时】：1:1 像素级复刻你跑通的命令！不挂任何 pflash 固件，硬盘在先，ISO 在后
            let iso_path = $"($ROOT)/result/iso/($iso)"
            $args ++= [
                -drive $"file=($cow),if=virtio,format=qcow2"
                -drive $"file=($iso_path),media=cdrom"
                -boot d
            ]
        } else {
            # 【不带参数时】：必须先确保 VARS 文件存在
            if not ($OVMF_VARS | path exists) {
                mkdir ($OVMF_VARS | path dirname)
                cp $OVMF_VARS_SRC $OVMF_VARS
                chmod 644 $OVMF_VARS
            }

            # 挂载 UEFI 固件 + 硬盘，秒进你的磁盘系统
            $args ++= [
                -drive $"if=pflash,format=raw,unit=0,readonly=on,file=($OVMF_CODE)"
                -drive $"if=pflash,format=raw,unit=1,file=($OVMF_VARS)"
                -drive $"file=($cow),if=virtio,format=qcow2"
                -boot c
            ]
        }

        # 3. 完美拉起 QEMU
        qemu-system-x86_64 ...$args
    }

}
