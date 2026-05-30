{ pkgs, ... }: {
  # WebAssembly
  environment.systemPackages = with pkgs; [
    wasmtime
  ];
}
