{ config, inputs, lib, pkgs, seamRoot, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  seamConfig = "${seamRoot}/dots/.config";

  qmlPackages = with pkgs.qt6Packages; [
    qt5compat
    qtdeclarative
    qtimageformats
    qtmultimedia
    qtpositioning
    qtquicktimeline
    qtsensors
    qtsvg
    qtvirtualkeyboard
    qtwayland
  ] ++ (with pkgs.kdePackages; [
    kirigami
    kirigami-addons
    qqc2-desktop-style
    syntax-highlighting
  ]);

  quickshell = pkgs.symlinkJoin {
    name = "quickshell-seam";
    paths = [ inputs.quickshell.packages.${system}.default ];
    nativeBuildInputs = [ pkgs.makeWrapper ];

    postBuild = ''
      for bin in "$out/bin/qs" "$out/bin/quickshell"; do
        if [ -e "$bin" ]; then
          wrapProgram "$bin" \
            --prefix NIXPKGS_QT6_QML_IMPORT_PATH : ${lib.makeSearchPath "lib/qt-6/qml" qmlPackages} \
            --prefix QT_PLUGIN_PATH : ${lib.makeSearchPath "lib/qt-6/plugins" qmlPackages} \
            --prefix XDG_DATA_DIRS : ${lib.makeSearchPath "share" qmlPackages}
        fi
      done
    '';
  };
in
{
  # Use the Quickshell flake directly and deploy the repository config.
  home.packages = [
    quickshell
  ] ++ qmlPackages ++ (with pkgs; [
    bluez
    cava
    ddcutil
    file
    imagemagick
    kdePackages.kdialog
    libnotify
    networkmanager
    xdg-utils
    yq-go
  ]);

  xdg.configFile."quickshell".source =
    config.lib.file.mkOutOfStoreSymlink "${seamConfig}/quickshell";
}
