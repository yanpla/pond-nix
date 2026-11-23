# Pond interface on NixOS: Pond's login screen (SDDM greeter in niri) and the
# Pond shell running on niri.
{
  config,
  lib,
  pkgs,
  # Pond's QML plugins and quickshell must share one Qt (see common.nix).
  pondPkgs,
  ...
}:

let
  cfg = config.pond.interface;
  pond = config.pond.package;
  vicinae = config.pond.vicinaePackage;
  share = "${pond}/share/pond-interface";

  python = pondPkgs.python3.withPackages (ps: [
    ps.pyqt6
    ps.pygobject3
  ]);

  # Commands the shell and its helper scripts run.
  runtimeDeps = with pondPkgs; [
    python
    networkmanager # nmcli
    iw
    brightnessctl
    ddcutil
    pulseaudio # pactl
    wl-clipboard
    zenity
    fastfetch
    imagemagick
    libcanberra-gtk3
    glib # gsettings
    getent
    coreutils
    config.programs.niri.package
    pkgs.systemd
  ];

  # `qs` / `quickshell` that can find Pond's QML modules and tools.
  quickshell = pondPkgs.symlinkJoin {
    name = "quickshell-pond";
    paths = [ pondPkgs.quickshell ];
    nativeBuildInputs = [ pondPkgs.makeWrapper ];
    postBuild = ''
      for bin in qs quickshell; do
        wrapProgram $out/bin/$bin \
          --prefix QML_IMPORT_PATH : ${pond}/lib/qt-6/qml \
          --prefix PATH : ${lib.makeBinPath runtimeDeps}
      done
    '';
  };

  # Pond's shell-owned niri config (~/.config/niri/shell), optionally with a
  # different default width for new windows.
  niriShellConfig = pkgs.runCommand "pond-niri-shell-config" { } (
    ''
      cp -r ${share}/config/niri/shell $out
      chmod -R u+w $out
    ''
    + lib.optionalString (cfg.defaultColumnWidth != null) ''
      substituteInPlace $out/layout.kdl --replace-fail \
        '    always-center-single-column' \
        '    always-center-single-column
          default-column-width { proportion ${columnWidth}; }'
    ''
  );

  # Seeds ~/.config with Pond's default niri/kitty config (like Arch's
  # /etc/skel), never overwriting files that already exist.
  setupScript = pkgs.writeShellScript "pond-user-setup" ''
    cfg="''${XDG_CONFIG_HOME:-$HOME/.config}"
    mkdir -p "$cfg/niri/cfg" "$cfg/kitty" "$HOME/Pictures/Wallpapers"
    cp -n --no-preserve=mode ${share}/config/niri/config.kdl "$cfg/niri/config.kdl"
    cp -n --no-preserve=mode ${share}/config/niri/cfg/*.kdl "$cfg/niri/cfg/"
    cp -n --no-preserve=mode ${share}/config/kitty/kitty.conf "$cfg/kitty/kitty.conf"
    # Shell-owned files track the installed version.
    ln -sfn ${niriShellConfig} "$cfg/niri/shell"
    [ -e "$cfg/kitty/current-theme.conf" ] || ln -s ${share}/config/kitty/themes/default.conf "$cfg/kitty/current-theme.conf"
  '';

  # SDDM built against the same Qt as Pond's QML plugins, with everything the
  # greeter imports. The NixOS module appends Qt packages from the system
  # channel via `.override`; ignore that so no older Qt plugins sneak in.
  sddm =
    let
      wrapped = pondPkgs.kdePackages.sddm.override {
        extraPackages = with pondPkgs.kdePackages; [
          pond
          qtsvg
          qtwayland
        ];
      };
    in
    wrapped // { override = _: wrapped; };

  # toString prints floats as 0.700000; trim the trailing zeros.
  columnWidth = builtins.head (
    builtins.match "([0-9]*\\.[0-9]*[1-9]|[0-9]*)\\.?0*" (toString cfg.defaultColumnWidth)
  );

  perUser = attrs: lib.genAttrs config.pond.users (_: attrs);
in
{
  options.pond.interface = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.pond.enable;
      defaultText = lib.literalExpression "config.pond.enable";
      description = "Pond's desktop: the Pond shell on niri, with Pond's login screen.";
    };

    displayManager.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use Pond's login screen (an SDDM greeter running in niri).";
    };

    launcher.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Pond's launcher (vicinae fork, Super+Space) and its daemon.";
    };

    seedUserConfig = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Copy Pond's default niri and kitty config into each user's ~/.config
        on login (existing files are never overwritten), and keep
        ~/.config/niri/shell linked to the installed version.
      '';
    };

    defaultColumnWidth = lib.mkOption {
      type = lib.types.nullOr lib.types.float;
      default = null;
      example = 0.7;
      description = ''
        Width of new windows as a fraction of the screen. `null` (the default)
        keeps niri's own default, half the screen.
      '';
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        xwayland-satellite # X11 apps under niri
        kitty
        nautilus # file manager Pond opens for the filesystem
        wl-clipboard
        fastfetch
        capitaine-cursors
        adwaita-icon-theme
      ];
      defaultText = lib.literalMD "xwayland-satellite, kitty, nautilus, wl-clipboard, fastfetch, cursor and icon themes";
      description = "Apps installed alongside the shell (Pond's defaults).";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        programs.niri.enable = true;

        environment.systemPackages = [
          pond
          quickshell
        ]
        ++ cfg.extraPackages;

        environment.etc = {
          "xdg/quickshell/pond-shell".source = "${share}/shell";
          "xdg/quickshell/pond-lockscreen".source = "${share}/lockscreen";
          "xdg/fastfetch/config.jsonc".source = "${share}/config/fastfetch/config.jsonc";
          "xdg/kitty/kitty.conf".source = "${share}/config/kitty/etc/kitty.conf";
        };

        fonts.packages = [
          pond # Onest, Advent Pro, fastfetch glyphs
          pkgs.ibm-plex
          pkgs.jetbrains-mono
        ];

        # Services the shell talks to.
        services.upower.enable = true;
        services.power-profiles-daemon.enable = lib.mkDefault true;
        services.udev.packages = [ pkgs.brightnessctl ];
        hardware.i2c.enable = true; # ddcutil (external monitor brightness)

        users.users = perUser {
          extraGroups = [
            "video"
            "i2c"
          ];
        };
      }

      (lib.mkIf cfg.displayManager.enable {
        services.displayManager.sddm = {
          enable = true;
          package = sddm;
          wayland.enable = true;
          wayland.compositorCommand = "${lib.getExe config.programs.niri.package} --config ${share}/lockscreen/greeter/niri.kdl";
          theme = "greeter";
          settings.Theme.ThemeDir = lib.mkForce "${share}/lockscreen";
        };
      })

      (lib.mkIf cfg.launcher.enable {
        environment.systemPackages = [ vicinae ];
        hardware.uinput.enable = true; # vicinae paste/typing
        users.users = perUser { extraGroups = [ "uinput" ]; };

        # vicinae reads keyboard input through this helper; Pond's Arch
        # package grants it cap_dac_override with setcap.
        security.wrappers.vicinae-input-server = {
          source = "${vicinae}/libexec/vicinae/vicinae-input-server";
          capabilities = "cap_dac_override+ep";
          owner = "root";
          group = "root";
        };

        # The launcher daemon. `vicinae toggle` (Super+Space) only talks to
        # this; without it the launcher never appears.
        systemd.user.services.vicinae = {
          description = "Vicinae launcher daemon";
          partOf = [ "graphical-session.target" ];
          after = [ "graphical-session.target" ];
          wantedBy = [ "graphical-session.target" ];
          # Apps launched from vicinae inherit this; NixOS units otherwise
          # only get a minimal PATH.
          environment.PATH = lib.mkForce (
            lib.concatStringsSep ":" [
              "/run/wrappers/bin"
              "%h/.nix-profile/bin"
              "/etc/profiles/per-user/%u/bin"
              "/nix/var/nix/profiles/default/bin"
              "/run/current-system/sw/bin"
            ]
          );
          serviceConfig = {
            ExecStart = "${vicinae}/bin/vicinae server --replace";
            Restart = "always";
            RestartSec = 2;
          };
        };
      })

      (lib.mkIf cfg.seedUserConfig {
        systemd.user.services.pond-user-setup = {
          description = "Seed Pond's default niri and kitty config";
          wantedBy = [ "default.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = setupScript;
          };
        };
      })
    ]
  );
}
