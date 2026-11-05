{
  description = "Pond (bflycomputer's desktop) for NixOS: interface, boot splash, GRUB theme and system optimizations";

  inputs = {
    # Pond needs Qt >= 6.12, so its Qt parts are built from unstable no matter
    # which nixpkgs the host uses.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    pond-interface = {
      url = "github:bflycomputer/pond-interface";
      flake = false;
    };
    pond-vicinae.url = "github:bflycomputer/vicinae";
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      common = import ./modules/common.nix inputs;
      withCommon = module: {
        imports = [
          common
          module
        ];
      };
    in
    {
      nixosModules = {
        # Everything; enable with `pond.enable = true;` or per part.
        default = {
          imports = [
            common
            ./modules/interface.nix
            ./modules/plymouth.nix
            ./modules/grub.nix
            ./modules/gtk.nix
            ./modules/optimizations.nix
          ];
        };
        interface = withCommon ./modules/interface.nix;
        plymouth = withCommon ./modules/plymouth.nix;
        grub = withCommon ./modules/grub.nix;
        gtk = withCommon ./modules/gtk.nix;
        optimizations = withCommon ./modules/optimizations.nix;
      };

      packages = forAllSystems (
        system:
        let
          eval = nixpkgs.lib.evalModules {
            modules = [
              common
              { _module.args.pkgs = nixpkgs.legacyPackages.${system}; }
            ];
          };
        in
        {
          pond-interface = eval.config.pond.package;
          vicinae = eval.config.pond.vicinaePackage;
          default = self.packages.${system}.pond-interface;
        }
      );

      # `nix flake check` evaluates a sample system with everything enabled.
      checks = forAllSystems (system: {
        eval =
          let
            sample = nixpkgs.lib.nixosSystem {
              modules = [
                self.nixosModules.default
                {
                  nixpkgs.hostPlatform = system;
                  pond.enable = true;
                  pond.users = [ "pond" ];
                  users.users.pond.isNormalUser = true;
                  fileSystems."/" = {
                    device = "/dev/null";
                    fsType = "ext4";
                  };
                  boot.loader.grub.efiInstallAsRemovable = true;
                  boot.loader.efi.canTouchEfiVariables = false;
                  system.stateVersion = "26.05";
                }
              ];
            };
          in
          nixpkgs.legacyPackages.${system}.writeText "pond-eval" (
            builtins.unsafeDiscardStringContext sample.config.system.build.toplevel.drvPath
          );
      });
    };
}
