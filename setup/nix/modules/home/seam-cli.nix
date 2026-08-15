{ inputs, pkgs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  seam-cli = inputs.seam-cli.packages.${system}.default.overrideAttrs {
    # Upstream's cleanSourceWith filter excludes src/templates/wallpaper.txt,
    # even though the Rust binary embeds it with include_str!.
    src = inputs.seam-cli;
  };
in
{
  home.packages = [ seam-cli ];
}
