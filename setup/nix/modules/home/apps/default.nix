{ config, lib, pkgs, seamRoot, ... }:

let
  seamConfig = "${seamRoot}/dots/.config";
  vscodeMarketplace = pkgs.nix-vscode-extensions.vscode-marketplace;

  vscodeExtensions = with vscodeMarketplace; [
    catppuccin.catppuccin-vsc-icons
    charliermarsh.ruff
    cschlosser.doxdocgen
    esbenp.prettier-vscode
    haikalllp.matugen-theme
    jnoortheen.nix-ide
    llvm-vs-code-extensions.vscode-clangd
    ms-python.python
    ms-python.vscode-pylance
    theqtcompany.qt-qml
    theqtcompany.qt-core
  ];
in
{
  home.packages = [
    pkgs.vesktop
    pkgs.zed-editor
  ];

  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
  };

  # Some VS Code extensions, including haikalllp.matugen-theme, write runtime
  # files inside their own extension directories. Nix-store symlinks are
  # read-only, so install every extension as a writable copy while still
  # sourcing the extension versions from nix-vscode-extensions.
  home.activation.installWritableVscodeExtensions =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      extensions_dir="${config.home.homeDirectory}/.vscode/extensions"

      install_extension() {
        source_dir="$1"
        unique_id="$2"
        version="$3"
        target_dir="$extensions_dir/$unique_id-$version"

        run rm $VERBOSE_ARG -rf "$extensions_dir/$unique_id" "$target_dir"
        run mkdir $VERBOSE_ARG -p "$extensions_dir"
        run cp $VERBOSE_ARG -R "$source_dir" "$target_dir"
        run chmod $VERBOSE_ARG -R u+w "$target_dir"
      }

      ${lib.concatMapStringsSep "\n" (extension: ''
        install_extension \
          "${extension}/share/vscode/extensions/${extension.vscodeExtUniqueId}" \
          "${extension.vscodeExtUniqueId}" \
          "${extension.version}"
      '') vscodeExtensions}

      run mkdir $VERBOSE_ARG -p "$extensions_dir/haikalllp.matugen-theme-1.0.2/themes"
      run rm $VERBOSE_ARG -f "$extensions_dir/extensions.json" "$extensions_dir/.extensions-immutable.json"
    '';

  # Copy app configs instead of symlinking whole app directories. These apps
  # write credentials, cookies, cache, and local storage under their config
  # roots, so only copy the safe declarative files from dots.
  home.activation.copySafeAppConfigs =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      config_home="${config.xdg.configHome}"
      source_config="${seamConfig}"

      ensure_real_dir() {
        target="$1"
        if [ -L "$target" ]; then
          run rm $VERBOSE_ARG "$target"
        fi
        run mkdir $VERBOSE_ARG -p "$target"
      }

      copy_file() {
        source_file="$1"
        target_file="$2"
        if [ -f "$source_file" ]; then
          run mkdir $VERBOSE_ARG -p "$(dirname "$target_file")"
          run cp $VERBOSE_ARG "$source_file" "$target_file"
        fi
      }

      copy_dir() {
        source_dir="$1"
        target_dir="$2"
        if [ -d "$source_dir" ]; then
          if [ -L "$target_dir" ]; then
            run rm $VERBOSE_ARG "$target_dir"
          fi
          run mkdir $VERBOSE_ARG -p "$target_dir"
          run cp $VERBOSE_ARG -R "$source_dir/." "$target_dir/"
        fi
      }

      ensure_real_dir "$config_home/Code"
      ensure_real_dir "$config_home/Code/User"
      copy_file "$source_config/Code/User/settings.json" "$config_home/Code/User/settings.json"
      copy_file "$source_config/Code/User/keybindings.json" "$config_home/Code/User/keybindings.json"
      copy_dir "$source_config/Code/User/snippets" "$config_home/Code/User/snippets"

      ensure_real_dir "$config_home/vesktop"
      copy_file "$source_config/vesktop/settings.json" "$config_home/vesktop/settings.json"
      copy_dir "$source_config/vesktop/settings" "$config_home/vesktop/settings"
      copy_dir "$source_config/vesktop/themes" "$config_home/vesktop/themes"

      ensure_real_dir "$config_home/zed"
      copy_file "$source_config/zed/settings.json" "$config_home/zed/settings.json"
      copy_dir "$source_config/zed/themes" "$config_home/zed/themes"
    '';
}
