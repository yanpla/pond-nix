Scripts from Pond's `pond-system-optimizations` package (1.4.1, itself based
on CachyOS-Settings; GPL-3.0-only, `iw-set-regdomain` ISC). Changes for NixOS:
store paths substituted in `../optimizations.nix` (`@zonetab@`, `@ldso@`),
tools called through PATH instead of /usr/bin, and zink-run pointed at
/run/opengl-driver.
