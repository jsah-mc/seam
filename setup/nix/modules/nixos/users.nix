{ pkgs, user, ... }:

{
  programs.zsh.enable = true;

  users.users.${user} = {
    isNormalUser = true;
    description = "Joseph Sah";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.zsh;
    packages = [ pkgs.kdePackages.kate ];
  };
}
