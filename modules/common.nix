# Options shared by every Pond module: the master switch, the users Pond
# applies to, and the packages built from this flake's inputs.
inputs:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkOption types;
  system = pkgs.stdenv.hostPlatform.system;

  # Pond's fork of the vicinae launcher (pond-launcher on Arch): adds the
  # pond-* themes the appearance settings switch between.
  # The fork builds vicinae with gcc15Stdenv, but its numen dependency gets the
  # nixpkgs default compiler (now GCC 16); their std::format ABIs differ and
  # the final link fails. Build numen with the same GCC 15 toolchain.
  vicinae =
    let
      v = inputs.pond-vicinae;
      forkPkgs = v.inputs.nixpkgs.legacyPackages.${system};
      numen = v.inputs.numen.packages.${system}.numen.override {
        stdenv = forkPkgs.gcc15Stdenv;
        withRepl = false;
      };
    in
    v.packages.${system}.default.override { inherit numen; };
in
{
  # Deduplicates this module when several Pond modules are imported.
  key = "pond-nix/common";

  options.pond = {
    enable = lib.mkEnableOption ''
      everything Pond: the desktop interface, boot splash, GRUB theme, dark
      GTK theme and system optimizations. Each part can still be turned off
      individually (e.g. `pond.grub.enable = false;`)
    '';

    users = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "alice" ];
      description = ''
        Users that get the groups Pond needs (video, i2c and uinput for the
        interface, audio for the realtime audio limits).
      '';
    };

    pkgs = mkOption {
      type = types.raw;
      default = inputs.nixpkgs.legacyPackages.${system};
      defaultText = lib.literalExpression "pond-nix.inputs.nixpkgs.legacyPackages.\${system}";
      description = ''
        Package set Pond's Qt parts (the interface, quickshell, the SDDM
        greeter) are built from. Pond needs Qt >= 6.12, so this defaults to
        the nixos-unstable pinned by this flake rather than your system's
        nixpkgs.
      '';
    };

    src = mkOption {
      type = types.path;
      default = inputs.pond-interface;
      defaultText = lib.literalExpression "pond-nix.inputs.pond-interface";
      description = "Source of pond-interface (shell, lockscreen, plymouth and GRUB themes).";
    };

    package = mkOption {
      type = types.package;
      default = config.pond.pkgs.callPackage ../pkgs/pond-interface.nix { src = config.pond.src; };
      defaultText = lib.literalMD "pond-interface built from `pond.src` with `pond.pkgs`";
      description = "The Pond interface package.";
    };

    vicinaePackage = mkOption {
      type = types.package;
      default = vicinae;
      defaultText = lib.literalMD "Pond's vicinae fork";
      description = "The launcher package (Pond's fork of vicinae).";
    };
  };
}
