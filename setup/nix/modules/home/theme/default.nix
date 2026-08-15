{ config, lib, pkgs, ... }:

{
  fonts.fontconfig.enable = true;

  gtk = {
    enable = true;

    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };

    iconTheme = {
      name = "breeze";
      package = pkgs.kdePackages.breeze-icons;
    };

    cursorTheme = {
      name = "breeze_cursors";
      package = pkgs.kdePackages.breeze;
      size = 24;
    };

    font = {
      name = "Noto Sans";
      package = pkgs.noto-fonts;
      size = 10;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-button-images = true;
      gtk-decoration-layout = "icon:minimize,maximize,close";
      gtk-menu-images = true;
      gtk-primary-button-warps-slider = true;
      gtk-toolbar-style = 3;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-decoration-layout = "icon:minimize,maximize,close";
      gtk-primary-button-warps-slider = true;
    };
  };

  home = {
    packages = with pkgs; [
      darkly
      nerd-fonts.jetbrains-mono
      # Nix equivalent of Arch's ttf-material-symbols-variable-git.
      material-symbols
      qt6Packages.qt6ct
      tela-circle-icon-theme
    ];

    sessionVariables.QT_QPA_PLATFORMTHEME = "qt6ct";
  };

  # These files predate Home Manager and contain the settings now declared
  # above. Allow Home Manager to replace only these known configuration files.
  home.file.${config.gtk.gtk2.configLocation}.force = lib.mkForce true;
  xdg.configFile."gtk-3.0/settings.ini".force = lib.mkForce true;
  xdg.configFile."gtk-4.0/settings.ini".force = lib.mkForce true;

  xdg.configFile."qt6ct/qt6ct.conf".text = ''
    [Appearance]
    color_scheme_path=~/.local/share/color-schemes/Seam.colors
    custom_palette=true
    icon_theme=Tela-circle
    standard_dialogs=default
    style=Darkly

    [Fonts]
    fixed="monospace,9,-1,2,400,0,0,0,0,0,0,0,0,0,0,1,,0,0"
    general="Noto Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0"

    [Interface]
    activate_item_on_single_click=1
    buttonbox_layout=0
    cursor_flash_time=1000
    dialog_buttons_have_icons=1
    double_click_interval=400
    gui_effects=@Invalid()
    keyboard_scheme=2
    menus_have_icons=true
    show_shortcuts_in_context_menus=true
    stylesheets=@Invalid()
    toolbutton_style=4
    underline_shortcut=1
    wheel_scroll_lines=3

    [Troubleshooting]
    force_raster_widgets=1
    ignored_applications=@Invalid()
  '';
}
