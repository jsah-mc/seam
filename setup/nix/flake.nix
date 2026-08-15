{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dots = {
      url = "path:/home/joseph/seam/dots";
      flake = false;
    };
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    seam-cli = {
      url = "github:jsah-mc/seam-cli";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, seam-cli, ... }:
    let
      localConfig =
        if builtins.pathExists ./seam.local.nix
        then import ./seam.local.nix
        else import ./hosts/jsnixy/variables.nix;
      hostname = localConfig.hostname or "jsnixy";
      system = localConfig.system or "x86_64-linux";
      user = localConfig.user or "joseph";
      seamRoot = localConfig.seamRoot or "/home/${user}/seam";
      enableNvidia = localConfig.enableNvidia or false;
      enableSecureBoot = localConfig.enableSecureBoot or false;
      hardwareConfiguration =
        localConfig.hardwareConfiguration or ./hosts/jsnixy/hardware-configuration.nix;
    in
    {
      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit enableNvidia enableSecureBoot hostname user; };
        modules = [
          hardwareConfiguration
          {
            nixpkgs.overlays = [
              inputs.nix-vscode-extensions.overlays.default
            ];
          }
          ./modules/nixos
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit inputs hostname seamRoot user; };
              users.${user} = import ./modules/home;
              backupFileExtension = "seam.bak";
            };
          }
        ];
      };

      packages = builtins.mapAttrs (packageSystem: pkgs: {
        hello = pkgs.hello;

        default = self.packages.${packageSystem}.hello;
      }) nixpkgs.legacyPackages;
    };
}
