{ config, pkgs, seamRoot, ... }:

let
  seamConfig = "${seamRoot}/dots/.config";
in
{
  # Keep the Lua configuration writable so Seam can regenerate colors.lua.
  xdg.configFile."hypr".source =
    config.lib.file.mkOutOfStoreSymlink "${seamConfig}/hypr";

  home.packages = with pkgs; [
    brightnessctl
    chromium
    grim
    hypridle
    hyprpicker
    hyprsunset
    jq
    kdePackages.dolphin
    kitty
    playerctl
    slurp
    wl-clipboard
  ];
}
