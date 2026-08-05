{ ... }: {
  rime.octagram.enable = true;

  # https://github.com/amzxyz/RIME-LMDG/releases/download/LTS/wanxiang-lts-zh-hans.gram
  rime.wanxiang.src = {
    url = "file:///nix/store/zlq9gvhynkvc2hial3310yw39kb32y3i-wanxiang-lts-zh-hans.gram";
    narHash = "sha256-apW5hlRjyRrJgk6eJ5IGUNbn+Y6y/LMXtB6go9EOG+0=";
  };
}
