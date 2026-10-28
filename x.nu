const ROOT = path self .
const OFFICIAL_SUBSTITUTER = 'https://cache.nixos.org'

def cmpl-hosts [] {
    cd $ROOT
    nix flake show --json | from json | get nixosConfigurations | columns
}

# substituter 覆盖参数（空=不传，沿用 flake.nix 声明的 nixSubstituters）
# 源挂掉时靠它救急：替换整表（--option substituters）才能剔除坏源，
# extra-substituters 只能追加，管不了"某个源不可用"。
def substituter-args [
    substituters?: list<string>   # 替换整表，顺序即尝试顺序
    harmonia?: list<string>       # 追加，在替换结果之上叠加
    official: bool = false        # 强制官方源，压过上面两个
]: nothing -> list<string> {
    # 强制官方源：镜像全挂/首选用官方时的最短路径，-s 和 --harmonia 一律不生效
    if $official {
        return [--option substituters $OFFICIAL_SUBSTITUTER]
    }
    # 未传 flag 时 nu 给的是 nothing，不能直接进 list 参数
    let substituters = $substituters | default []
    let harmonia = $harmonia | default []
    mut a = []
    if ($substituters | is-not-empty) {
        $a ++= [--option substituters ($substituters | str join ' ')]
    }
    if ($harmonia | is-not-empty) {
        $a ++= [--option extra-substituters ($harmonia | str join ' ')]
    }
    $a
}

export def switch [
    host: string@cmpl-hosts = 'workstations_orbit'
    --remote: string
    --official(-o)                          # 只用官方源 cache.nixos.org，忽略 -s/--harmonia
    --substituters(-s): list<string> = []   # 临时替换 substituter 列表（默认源全挂时仍能构建）
    --harmonia: list<string> = []           # 临时追加 harmonia 缓存
] {
    cd $ROOT
    $env.NIXOS_LABEL = (git log -1 --pretty=format:"%s" | sed 's/ /_/g')
    mut args = [
        switch
        --flake $".#($host)"
    ]
    $args ++= (substituter-args $substituters $harmonia $official)
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
    --official(-o)                          # 只用官方源 cache.nixos.org，忽略 -s/--harmonia
    --substituters(-s): list<string> = []   # 临时替换 substituter 列表（默认源全挂时仍能构建）
    --harmonia: list<string> = []           # 临时追加 harmonia 缓存
] {
    let opts = substituter-args $substituters $harmonia $official
    mut args = []
    # nh 用 `--` 把后续参数透传给 nix build
    if not ($opts | is-empty) { $args ++= [-- ...$opts] }
    nh os build $"($ROOT)#($host)" ...$args
}

export def sync [] {
    cd $ROOT
    toggle proxy http://127.0.0.1:7890
    sudo -E nix flake update
}

export def check [] {
    cd $ROOT
    sudo nix flake check
}

export def build-remote [
    host:string@cmpl-hosts
    --target: string
    --build: string = 'localhost'
] {
    mut args = [
        --flake $".#($host)"
        --target-host $target
        --build-host $build
    ]
    nixos-rebuild build ...$args
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
export use mount

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

    def cmpl-link [] {
        ls -l /nix/var/nix/gcroots/auto
        | select name target
        | where {|x| $x.target | str starts-with '/nix/store' }
        | update target {|x| $x.target | str substring 44.. }
        | rename value description
    }

    def cmpl-id [] {
        cmpl-link | update value {|x| $x.value | path parse | get stem  }
    }

    export def gcroot [
      gcroot: string@cmpl-id
      file: path
    ] {
        let h = nix store add-file $file
        sudo ln -sf $h /nix/var/nix/gcroots/auto/($gcroot)
        # fetchTree 用 prefetch 后的新 store path 的 NAR hash
        let prefetched = (nix store prefetch-file $"file://($h)" --json | from json).storePath
        let p = nix hash path $prefetched
        $'url = "file://($h)";(char newline)narHash = "($p)";'
    }

    export def ungcroot [link: path@cmpl-link] {
        sudo rm -f $link
    }
}
export use utils

export def deployment [
    host: string@cmpl-hosts
    target
    --port: string
    --off-line
    --kexec: path = '~/pub/Application/Linux/nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz'
] {
    mut args = [
        --kexec $kexec
        --flake ($env.PWD)#($host) $target
    ]
    if ($port | is-not-empty) {
        $args ++= [--post-kexec-ssh-port $port]
    }
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

    export def xrun [
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
            -vga qxl
            -netdev "user,id=net0,hostfwd=tcp::2266-:2222,hostfwd=tcp::2267-:22"
            -device "virtio-net-pci,netdev=net0"
            -device virtio-balloon-pci
            -spice "port=5900,addr=127.0.0.1,disable-ticketing=on"
            -device qemu-xhci
            -device usb-tablet
        ]

        # 2. 确保 OVMF_VARS 文件存在（ISO 和硬盘启动都需要 UEFI）
        if not ($OVMF_VARS | path exists) {
            mkdir $"($OVMF_VARS | path dirname)"
            cp $OVMF_VARS_SRC $OVMF_VARS
            chmod 644 $OVMF_VARS
        }

        # 3. UEFI 固件（ISO 和硬盘启动都挂 pflash，保持 UEFI 模式一致）
        $args ++= [
            -drive $"if=pflash,format=raw,unit=0,readonly=on,file=($OVMF_CODE)"
            -drive $"if=pflash,format=raw,unit=1,file=($OVMF_VARS)"
        ]

        # 4. 核心分流：有 ISO 时从 CDROM 启动，无 ISO 时从硬盘启动
        #    bootindex 是设备层属性，需将 drive 后端与设备分开定义
        if ($iso | is-not-empty) {
            let iso_path = $"($ROOT)/result/iso/($iso)"
            $args ++= [
                -drive $"file=($cow),if=none,id=disk0,format=qcow2"
                -device "virtio-blk-pci,drive=disk0"
                -drive $"file=($iso_path),if=none,id=cd0,media=cdrom,readonly=on"
                -device "ide-cd,drive=cd0,bootindex=0"
            ]
        } else {
            $args ++= [
                -drive $"file=($cow),if=none,id=disk0,format=qcow2"
                -device "virtio-blk-pci,drive=disk0,bootindex=0"
            ]
        }

        # 3. 完美拉起 QEMU
        qemu-system-x86_64 ...$args
    }

    export def conn [] {
        remote-viewer spice://127.0.0.1:5900
    }
}
export use qemu
