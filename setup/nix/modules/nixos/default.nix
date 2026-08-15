{ enableNvidia, lib, ... }:

{
  imports = [
    ./boot.nix
    ./desktop.nix
    ./hyprland.nix
    ./locale.nix
    ./networking.nix
    ./packages.nix
    ./sound.nix
    ./users.nix
  ] ++ lib.optionals enableNvidia [
    ./nvidia.nix
  ];

  system.stateVersion = "26.05";
}
