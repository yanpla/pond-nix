# Pond's boot menu (pond-grub-config on Arch): the GRUB theme from
# /usr/share/grub/themes/pond and a hook that renames the menu entries.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.pond.grub;
  src = "${config.pond.src}/grub";

  # Only the chosen size is copied to /boot: NixOS loads every .pf2 in the
  # theme directory, and the other sizes would just take up space on the ESP.
  theme = pkgs.runCommand "grub-theme-pond-${cfg.scale}" { } ''
    mkdir -p $out/assets $out/f
    cp ${src}/layouts/theme-${cfg.scale}.txt $out/theme.txt
    cp -r ${src}/assets/${cfg.scale} $out/assets/
    cp ${src}/assets/fonts/onest-${cfg.scale}.pf2 $out/f/
  '';
in
{
  options.pond.grub = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.pond.enable;
      defaultText = lib.literalExpression "config.pond.enable";
      description = ''
        GRUB as the boot loader, with Pond's theme. Defaults to an EFI install
        (`efiSupport = true; device = "nodev";`); override those
        `boot.loader.grub` options for BIOS systems.
      '';
    };

    scale = lib.mkOption {
      type = lib.types.enum [
        "12"
        "17"
        "21"
        "32"
        "43"
        "64"
      ];
      default = "21";
      description = "Theme size: 21 suits a 1080p screen, 32 a 1440p one, 43 a 4K one.";
    };

    renameEntries = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''Show "Pond" instead of "NixOS" in the boot menu.'';
    };
  };

  config = lib.mkIf cfg.enable {
    boot.loader.timeout = lib.mkDefault 3;
    boot.loader.grub = {
      enable = true;
      efiSupport = lib.mkDefault true;
      device = lib.mkDefault "nodev";
      useOSProber = lib.mkDefault true; # list Windows etc.
      inherit theme;
      splashImage = null;
      # The theme's terminal font is "Unifont Regular 16" (GRUB's unicode.pf2).
      font = "${pkgs.grub2}/share/grub/unicode.pf2";
      gfxmodeEfi = lib.mkDefault "auto";
      gfxpayloadEfi = lib.mkDefault "keep";
      # Like Pond's pond-grub-update: shorter entry titles.
      extraInstallCommands = lib.mkIf cfg.renameEntries ''
        ${pkgs.gnused}/bin/sed -i \
          -e 's/^menuentry "NixOS" /menuentry "Pond" /' \
          -e 's/^submenu "NixOS - All configurations" /submenu "Pond - All configurations" /' \
          /boot/grub/grub.cfg
      '';
    };
  };
}
