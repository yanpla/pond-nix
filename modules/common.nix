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
      default = pkgs.callPackage ../pkgs/pond-interface.nix { src = self.inputs.pond-interface; };
      description = "The Pond interface package.";
    };

    vicinaePackage = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${system}.vicinae;
      defaultText = lib.literalExpression "pond-nix.packages.\${system}.vicinae";
      description = "The launcher package (Pond's fork of vicinae).";
    };
  };
}
