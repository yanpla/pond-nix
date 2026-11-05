# Dark Adwaita for GTK apps (pond-shell's gtk settings.ini + gschema override).
{ config, lib, ... }:

let
  settings = ''
    [Settings]
    gtk-theme-name=Adwaita
    gtk-application-prefer-dark-theme=true
  '';
in
{
  options.pond.gtk.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.pond.enable;
    defaultText = lib.literalExpression "config.pond.enable";
    description = "Dark Adwaita as the default GTK theme, like Pond.";
  };

  config = lib.mkIf config.pond.gtk.enable {
    environment.etc = {
      "xdg/gtk-3.0/settings.ini".text = settings;
      "xdg/gtk-4.0/settings.ini".text = settings;
    };
    programs.dconf.profiles.user.databases = [
      {
        settings."org/gnome/desktop/interface" = {
          gtk-theme = "Adwaita";
          color-scheme = "prefer-dark";
        };
      }
    ];
  };
}
