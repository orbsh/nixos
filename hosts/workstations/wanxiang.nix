{ ... }: {
  rime.pinyin.octagram.enable = true;

  # https://github.com/amzxyz/RIME-LMDG/releases/download/LTS/wanxiang-lts-zh-hans.gram
  rime.pinyin.wanxiang.src = {
    url = "http://box.d/nixos/wanxiang-lts-zh-hans.gram";
    narHash = "sha256-apW5hlRjyRrJgk6eJ5IGUNbn+Y6y/LMXtB6go9EOG+0=";
  };
}
