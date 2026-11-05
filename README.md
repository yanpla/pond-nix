# pond-nix

[Pond](https://github.com/bflycomputer/pond-interface) for NixOS: the Pond
shell on niri, Pond's login screen, boot splash, GRUB theme, dark GTK theme,
and Pond's system optimizations (based on CachyOS-Settings). Each part is a
module you can turn on or off.

## Install

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    pond.url = "github:yanpla/pond-nix";
  };

  outputs = { nixpkgs, pond, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        ./configuration.nix
        pond.nixosModules.default
      ];
    };
  };
}
```

```nix
# configuration.nix
{
  pond.enable = true;        # everything below
  pond.users = [ "alice" ];  # gets the video/i2c/uinput/audio groups
}
```

Don't make `pond`'s `nixpkgs` follow yours unless yours is nixos-unstable:
Pond needs Qt >= 6.12, so its Qt parts are built from the unstable nixpkgs
pinned here. Everything else uses your system's nixpkgs.

## Options

`pond.enable` sets the default for every part. Turn parts off on their own,
or leave `pond.enable` off and turn on only what you want:

```nix
{
  pond.enable = true;
  pond.grub.enable = false;            # keep systemd-boot
  pond.optimizations.ananicy = false;  # but keep the other optimizations
}
```

| Option | Default | What it does |
| --- | --- | --- |
| `pond.enable` | `false` | Turn on every part below |
| `pond.users` | `[ ]` | Users added to the groups Pond needs |
| **Interface** | | |
| `pond.interface.enable` | `pond.enable` | Pond shell on niri |
| `pond.interface.displayManager.enable` | `true` | Pond's login screen (SDDM greeter in niri) |
| `pond.interface.launcher.enable` | `true` | Launcher (Pond's vicinae fork, Super+Space) |
| `pond.interface.seedUserConfig` | `true` | Copy default niri/kitty config into `~/.config` (never overwrites) |
| `pond.interface.defaultColumnWidth` | `null` | Width of new windows as a fraction of the screen, e.g. `0.7`; `null` keeps niri's default (0.5) |
| `pond.interface.extraPackages` | kitty, nautilus, ... | Apps installed alongside the shell |
| **Boot** | | |
| `pond.plymouth.enable` | `pond.enable` | Pond boot splash and quiet boot |
| `pond.plymouth.earlyKmsModules` | `[ ]` | GPU modules loaded early so the splash shows right away, e.g. `[ "amdgpu" ]` |
| `pond.grub.enable` | `pond.enable` | GRUB with Pond's theme (EFI; override `boot.loader.grub.*` for BIOS) |
| `pond.grub.scale` | `"21"` | Theme size: `21` for 1080p, `32` for 1440p, `43` for 4K |
| `pond.grub.renameEntries` | `true` | Show "Pond" instead of "NixOS" in the menu |
| **Look** | | |
| `pond.gtk.enable` | `pond.enable` | Dark Adwaita for GTK apps |
| **Optimizations** | | |
| `pond.optimizations.enable` | `pond.enable` | Default for all of the below |
| `pond.optimizations.tools` | | `game-performance`, `zink-run`, `kerver`, `topmem` |
| `pond.optimizations.memory` | | zram swap (zstd), memory sysctls, THP tuning |
| `pond.optimizations.oomd` | | systemd-oomd instead of freezing under memory pressure |
| `pond.optimizations.kernel` | | ntsync, no hardware watchdogs, quieter kernel log |
| `pond.optimizations.storage` | | I/O schedulers, SATA link power, no HDD spin-down |
| `pond.optimizations.audio` | | Realtime audio limits, rtkit, PCI latency, no sound card power saving on AC |
| `pond.optimizations.wifiRegdomain` | | Wi-Fi regulatory domain from the timezone |
| `pond.optimizations.systemd` | | Shorter timeouts, higher file limits, 50M journal |
| `pond.optimizations.ananicy` | | ananicy-cpp with CachyOS rules |
| `pond.optimizations.network` | | systemd-resolved DNS, Cloudflare time servers |

Advanced: `pond.pkgs` (package set for the Qt parts), `pond.src` (the
pond-interface source), `pond.package` and `pond.vicinaePackage`.

Most settings use `mkDefault`, so your own values win.

## Single modules

If you only want one part, import just that module:
`pond.nixosModules.{interface,plymouth,grub,gtk,optimizations}`. Each one is
off until you enable it (`pond.<part>.enable = true;` or `pond.enable = true;`).

## Packages

`nix build github:yanpla/pond-nix#pond-interface` (also `#vicinae`).
