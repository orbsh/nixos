{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    gcc
    cmake
    gnumake
    pkg-config
    curl.dev    # libcurl headers (curl/curl.h) for rdkafka-sys etc.
  ];
}
