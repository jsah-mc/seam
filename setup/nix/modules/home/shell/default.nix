{ inputs, lib, pkgs, seamRoot, ... }:

let
  seamHome = "${seamRoot}/dots";
in
{
  programs.zsh = {
    enable = true;

    autosuggestion.enable = true;
    fastSyntaxHighlighting.enable = true;

    initContent = lib.mkAfter ''
      source "${seamHome}/.zshrc"

      starship_transient_prompt_func() {
        starship module character
      }

      starship_transient_rprompt_func() {
        :
      }

      (( $+functions[enable_transience] )) && enable_transience
    '';
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = builtins.fromTOML (
      builtins.readFile "${inputs.dots}/.config/starship.toml"
    );
  };

  programs.kitty = {
    enable = true;
    shellIntegration.enableZshIntegration = true;
    extraConfig = ''
      include ${seamHome}/.config/kitty/kitty.conf
      include ~/.config/kitty/colors.conf
    '';
  };

  home.packages = with pkgs; [
    gh
    zoxide
    zsh
  ];

}
