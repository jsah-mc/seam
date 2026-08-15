{ pkgs, ... }:

{
  programs.nixvim = {
    enable = true;

    nixpkgs.source = pkgs.path;

    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    opts = {
      expandtab = true;
      number = true;
      relativenumber = true;
      shiftwidth = 2;
      smartindent = true;
      tabstop = 2;
      termguicolors = true;
    };

    clipboard.providers.wl-copy.enable = true;

    plugins = {
      lualine.enable = true;
      nix.enable = true;
      telescope.enable = true;
      treesitter.enable = true;
      web-devicons.enable = true;
    };
  };
}
