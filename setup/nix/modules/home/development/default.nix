{ pkgs, ... }:

{
  imports = [
    ./nixvim.nix
  ];

  home.packages = with pkgs; [
    cargo
    fd
    gcc
    git
    gnumake
    go
    lua-language-server
    nil
    nixpkgs-fmt
    nodejs
    pnpm
    python3
    ripgrep
    rustc
    github-cli
  ];
}
