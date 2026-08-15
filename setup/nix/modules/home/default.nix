{ inputs, user, ... }:

{
  imports = [
    inputs.nixvim.homeModules.nixvim
    ./apps
    ./development
    ./hyprland
    ./quickshell
    ./seam-cli.nix
    ./shell
    ./theme
  ];

  home = {
    username = user;
    homeDirectory = "/home/${user}";
    stateVersion = "26.05";
  };
  programs.home-manager.enable = true;
}
