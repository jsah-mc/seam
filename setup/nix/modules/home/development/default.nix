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
    github-cli
    gnumake
    go
    isort
    lua-language-server
    marksman
    nil
    nixpkgs-fmt
    nodejs
    pnpm
    prettierd
    pyright
    python3
    ripgrep
    rustc
    shfmt
    stylua
    taplo
    typescript-language-server
    vscode-langservers-extracted
    yaml-language-server
  ];
}
