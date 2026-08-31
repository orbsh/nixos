{ ... }: {
  rime.octagram.enable = true;

  # https://github.com/amzxyz/RIME-LMDG/releases/download/LTS/wanxiang-lts-zh-hans.gram
  rime.wanxiang.src = {
    url = "http://box.d/cache/wanxiang-lts-zh-hans.gram";
    narHash = "sha256-uIkCY74pXvBMy6FvNqCX9k5/dJ9FkIOKUdjEWjhY6/s=";
  };
}
