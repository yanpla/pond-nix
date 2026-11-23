# Pond's boot/shutdown animation (pond-plymouth-theme) and a quiet boot.
{
  config,
  options,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.pond.plymouth;

  # Newer nixpkgs removed the scripted initrd (systemd initrd is the only one
  # left) and with it these options; only set them where they still exist.
  available = opt: (opt.visible or true) != false;

  # Pond's theme, with its /usr paths pointed at the store.
  theme = pkgs.runCommand "plymouth-theme-pond" { } ''
    dir=$out/share/plymouth/themes/pond
    mkdir -p $dir
    cp -r ${config.pond.package.src}/plymouth/. $dir/
    chmod -R u+w $dir
    substituteInPlace $dir/pond.plymouth \
      --replace-fail /usr/share/plymouth/themes/pond $dir
  '';
in
{
  options.pond.plymouth = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.pond.enable;
      defaultText = lib.literalExpression "config.pond.enable";
      description = "Pond's boot splash, with kernel and systemd messages hidden.";
    };

    earlyKmsModules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "amdgpu" ];
      description = ''
        GPU kernel modules loaded in the initrd so the splash shows from the
        start of boot (e.g. "amdgpu", "i915", "nvidia").
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    boot.plymouth = {
      enable = true;
      theme = "pond";
      themePackages = [ theme ];
      # Pond renders at native resolution and scales per display itself.
      extraConfig = ''
        DeviceScale=1
      '';
    };
    boot.initrd = {
      kernelModules = cfg.earlyKmsModules;
    }
    // lib.optionalAttrs (available options.boot.initrd.systemd.enable) {
      systemd.enable = lib.mkDefault true; # plymouth from the very start of boot
      verbose = lib.mkDefault false;
    };
    boot.consoleLogLevel = lib.mkDefault 3;
    # Pond's GRUB_CMDLINE_LINUX_DEFAULT.
    boot.kernelParams = [
      "quiet"
      "splash"
      "udev.log_level=3"
      "rd.udev.log_level=3"
      "systemd.show_status=false"
      "vt.global_cursor_default=0"
    ];
  };
}
