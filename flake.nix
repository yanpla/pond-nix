{
  description = "Pond (bflycomputer's desktop) for NixOS: interface, boot splash, GRUB theme and system optimizations";

  inputs = {
    # Pond needs Qt >= 6.12 (nixos-unstable). Only make this follow your
    # nixpkgs if yours is nixos-unstable too.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    pond-interface = {
      url = "github:bflycomputer/pond-interface";
      flake = false;
    };
    pond-vicinae.url = "github:bflycomputer/vicinae";
  };

  outputs =
    {
      self,
      nixpkgs,
      pond-interface,
      pond-vicinae,
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      nixosModules.default = {
        imports = [
          (import ./modules/common.nix self)
          ./modules/interface.nix
          ./modules/plymouth.nix
          ./modules/grub.nix
          ./modules/gtk.nix
          ./modules/optimizations.nix
        ];
      };

      packages = forAllSystems (system: {
        pond-interface = nixpkgs.legacyPackages.${system}.callPackage ./pkgs/pond-interface.nix {
          src = pond-interface;
        };

        # Pond's fork of the vicinae launcher, with the pond-* themes.
        vicinae = pond-vicinae.packages.${system}.default;

        default = self.packages.${system}.pond-interface;
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      # Evaluates a sample system with everything enabled.
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
