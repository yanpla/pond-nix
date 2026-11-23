# pond-nix

[Pond](https://github.com/bflycomputer/pond-interface) for NixOS: the shell on
niri, login screen, boot splash, GRUB theme, GTK theme and system
optimizations.

## Install

```nix
# flake.nix
{
  inputs.pond.url = "github:yanpla/pond-nix";

  outputs = { nixpkgs, pond, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [ ./configuration.nix pond.nixosModules.default ];
    };
  };
}
```

```nix
# configuration.nix
{
  pond.enable = true;
  pond.users = [ "alice" ];
}
```

Every part can be turned off on its own, e.g. `pond.grub.enable = false;`.
All options are under `pond.*` in [`modules/`](modules).

Pond needs nixos-unstable (Qt >= 6.12).
