self:
{ lib, pkgs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  options.pond = {
    enable = lib.mkEnableOption ''
      everything Pond: the desktop interface, boot splash, GRUB theme, dark
      GTK theme and system optimizations. Each part can still be turned off
      individually (e.g. `pond.grub.enable = false;`)
    '';

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "alice" ];
      description = ''
        Users that get the groups Pond needs (video, i2c and uinput for the
        interface, audio for the realtime audio limits).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${system}.pond-interface;
      defaultText = lib.literalExpression "pond-nix.packages.\${system}.pond-interface";
      description = "The Pond interface package.";
    };

    vicinaePackage = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${system}.vicinae;
      defaultText = lib.literalExpression "pond-nix.packages.\${system}.vicinae";
      description = "The launcher package (Pond's fork of vicinae).";
    };
  };

  # Pond needs Qt >= 6.12, so its Qt parts are built from this flake's
  # nixos-unstable rather than the system's nixpkgs.
  config._module.args.pondPkgs = self.inputs.nixpkgs.legacyPackages.${system};
}
