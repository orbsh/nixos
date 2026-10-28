{ ... }: {
  rime.pinyin.octagram.enable = true;

  # https://github.com/amzxyz/RIME-LMDG/releases/download/LTS/wanxiang-lts-zh-hans.gram
  rime.pinyin.wanxiang.src = {
    url = "http://box.d/nixos/wanxiang-lts-zh-hans.gram";
    hash = "sha256-mdab7x5ErrKP9+6Eg5ClfFoQTTsdH0gns+jRR14aCvU=";
  };
}
