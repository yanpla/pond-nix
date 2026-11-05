# Pond's pond-system-optimizations package (1.4.1, based on CachyOS-Settings)
# translated to NixOS. Its scripts live in ./optimizations/.
# Left out: amdgpu/radeon si/cik options (only for GCN 1/2 GPUs), the nvidia
# runtime-PM udev rule (hardware.nvidia.powerManagement.finegrained installs
# the same), kernel.unprivileged_userns_clone (not in mainline kernels),
# dlss-swapper and sbctl-batch-sign (Arch-specific helpers).
{
  config,
  options,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.pond.optimizations;

  part =
    description:
    lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable;
      defaultText = lib.literalExpression "config.pond.optimizations.enable";
      inherit description;
    };

  script =
    name: deps:
    pkgs.runCommand name { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
      install -Dm755 ${./optimizations + "/${name}"} $out/bin/${name}
      patchShebangs $out/bin
      substituteInPlace $out/bin/${name} \
        --subst-var-by zonetab ${pkgs.tzdata}/share/zoneinfo/zone.tab \
        --subst-var-by ldso ${pkgs.stdenv.cc.bintools.dynamicLinker}
      wrapProgram $out/bin/${name} --prefix PATH : ${lib.makeBinPath deps}
    '';

  lua = pkgs.lua5_4.withPackages (ps: [ ps.luv ]);
  topmem = pkgs.runCommand "topmem" { } ''
    install -Dm755 ${./optimizations/topmem} $out/bin/topmem
    substituteInPlace $out/bin/topmem --replace-fail '#!/usr/bin/env lua' '#!${lua}/bin/lua'
  '';

  gamePerformance = script "game-performance" [
    config.services.power-profiles-daemon.package
    pkgs.systemd
    pkgs.gnugrep
  ];
  zinkRun = script "zink-run" [ ];
  kerver = script "kerver" (
    with pkgs;
    [
      systemd
      gnugrep
      gnused
      gzip
      procps
      findutils
      coreutils
    ]
  );
  pciLatency = script "pci-latency" [ pkgs.pciutils ];
  iwSetRegdomain = script "iw-set-regdomain" (
    with pkgs;
    [
      iw
      systemd
      util-linux # logger
      gnused
      coreutils
    ]
  );

  bash = "${pkgs.bash}/bin/bash";

  # Beats NixOS's own mkDefault sysctls, loses to plain user definitions.
  pondDefault = lib.mkOverride 900;
in
{
  options.pond.optimizations = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.pond.enable;
      defaultText = lib.literalExpression "config.pond.enable";
      description = ''
        Pond's system optimizations (from CachyOS-Settings). Turns on every
        part below; each can be disabled on its own.
      '';
    };

    tools = part "game-performance, zink-run, kerver and topmem commands.";
    memory = part "zram swap (zstd), memory sysctls and transparent hugepage tuning.";
    oomd = part "systemd-oomd: kill the worst offender under memory pressure instead of freezing.";
    kernel = part "ntsync module for Wine/Proton, no hardware watchdogs, quieter kernel log.";
    storage = part "Per-device I/O schedulers, SATA link power and no hard drive spin-down.";
    audio = part "Realtime audio limits, rtkit, PCI latency tuning and no sound card power saving on AC.";
    wifiRegdomain = part "Set the Wi-Fi regulatory domain from the timezone.";
    systemd = part "Shorter systemd timeouts, higher file limits and a 50M journal.";
    ananicy = part "ananicy-cpp process priorities with CachyOS rules.";
    network = part "DNS through systemd-resolved, time from Cloudflare.";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.tools {
      environment.systemPackages = [
        gamePerformance # `game-performance <cmd>`: performance power profile while it runs
        zinkRun # `zink-run <cmd>`: OpenGL through Vulkan (zink)
        kerver # kernel/CPU/scheduler report
        topmem # memory use per process, including swap
      ];
    })

    (lib.mkIf cfg.memory {
      zramSwap = {
        enable = lib.mkDefault true;
        algorithm = lib.mkDefault "zstd";
        priority = lib.mkDefault 100;
      };
      boot.kernelParams = [ "zswap.enabled=0" ]; # zram is used instead
      boot.kernel.sysctl = {
        "vm.swappiness" = pondDefault 150; # Pond raises it to 150 once zram is up
        "vm.vfs_cache_pressure" = pondDefault 50;
        "vm.dirty_bytes" = pondDefault 268435456;
        "vm.dirty_background_bytes" = pondDefault 67108864;
        "vm.dirty_writeback_centisecs" = pondDefault 1500;
        "vm.page-cluster" = pondDefault 0;
        "fs.file-max" = pondDefault 2097152;
        "net.core.netdev_max_backlog" = pondDefault 4096;
      };
      systemd.tmpfiles.rules = [
        "w! /sys/kernel/mm/transparent_hugepage/defrag - - - - defer+madvise"
        "w! /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_none - - - - 409"
      ];
    })

    (lib.mkIf cfg.oomd {
      systemd.oomd.enable = true;
      systemd.slices.system.sliceConfig = {
        ManagedOOMSwap = "kill";
        ManagedOOMMemoryPressure = "kill";
        ManagedOOMMemoryPressureLimit = "80%";
      };
      systemd.units."user-.slice" = {
        text = ''
          [Slice]
          ManagedOOMSwap=kill
          ManagedOOMMemoryPressure=kill
          ManagedOOMMemoryPressureLimit=80%
        '';
        overrideStrategy = "asDropin";
      };
      # ...but never pick the session itself (compositor, shell).
      systemd.user.units."session.slice" = {
        text = ''
          [Slice]
          ManagedOOMPreference=omit
        '';
        overrideStrategy = "asDropin";
      };
      # Let the user manager control cpu/io/memory of its own services.
      systemd.services."user@".serviceConfig.Delegate = "cpu cpuset io memory pids";
    })

    (lib.mkIf cfg.kernel {
      boot.kernelModules = [ "ntsync" ]; # Wine/Proton sync primitives
      boot.blacklistedKernelModules = [
        "iTCO_wdt"
        "sp5100_tco"
      ];
      boot.kernel.sysctl = {
        "kernel.nmi_watchdog" = pondDefault 0;
        "kernel.printk" = pondDefault "3 3 3 3";
        "kernel.kptr_restrict" = pondDefault 2;
      };
      boot.extraModprobeConfig = lib.mkIf (lib.elem "nvidia" config.services.xserver.videoDrivers) ''
        options nvidia NVreg_InitializeSystemMemoryAllocations=0
      '';
    })

    (lib.mkIf cfg.storage {
      services.udev.extraRules = ''
        # I/O schedulers
        ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
        ACTION=="add|change", KERNEL=="sd[a-z]*|mmcblk[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
        ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="kyber"

        # SATA links at full performance
        ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", ATTR{link_power_management_supported}=="1", ATTR{link_power_management_policy}=="*", ATTR{link_power_management_policy}="max_performance"

        # Hard drives: no APM spin-down
        ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ENV{ID_BUS}=="ata", RUN+="${pkgs.hdparm}/bin/hdparm -B 254 -S 0 /dev/%k"
      '';
    })

    (lib.mkIf cfg.audio {
      services.udev.extraRules = ''
        # Timers and CPU latency control for realtime audio
        KERNEL=="rtc0", GROUP="audio"
        KERNEL=="hpet", GROUP="audio"
        DEVPATH=="/devices/virtual/misc/cpu_dma_latency", OWNER="root", GROUP="audio", MODE="0660"

        # No sound card power saving on AC (avoids pops and lag); restored on battery
        ACTION=="add", SUBSYSTEM=="sound", KERNEL=="card*", DRIVERS=="snd_hda_intel", TEST!="/run/udev/snd-hda-intel-powersave", \
          RUN+="${bash} -c 'touch /run/udev/snd-hda-intel-powersave; \
            [[ $$(cat /sys/class/power_supply/BAT0/status 2>/dev/null) != \"Discharging\" ]] && \
            echo $$(cat /sys/module/snd_hda_intel/parameters/power_save) > /run/udev/snd-hda-intel-powersave && \
            echo 0 > /sys/module/snd_hda_intel/parameters/power_save'"
        SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="0", TEST=="/sys/module/snd_hda_intel", \
          RUN+="${bash} -c 'echo $$(cat /run/udev/snd-hda-intel-powersave 2>/dev/null || \
            echo 10) > /sys/module/snd_hda_intel/parameters/power_save'"
        SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="1", TEST=="/sys/module/snd_hda_intel", \
          RUN+="${bash} -c '[[ $$(cat /sys/module/snd_hda_intel/parameters/power_save) != 0 ]] && \
            echo $$(cat /sys/module/snd_hda_intel/parameters/power_save) > /run/udev/snd-hda-intel-powersave; \
            echo 0 > /sys/module/snd_hda_intel/parameters/power_save'"
      '';

      # Realtime scheduling: Pond's @audio limits, plus rtkit (which is how
      # PipeWire gets realtime priority on NixOS).
      security.pam.loginLimits = [
        {
          domain = "@audio";
          item = "rtprio";
          type = "-";
          value = "99";
        }
        {
          domain = "@audio";
          item = "nice";
          type = "-";
          value = "-11";
        }
      ];
      users.users = lib.genAttrs config.pond.users (_: {
        extraGroups = [ "audio" ];
      });
      security.rtkit.enable = true;
      systemd.services.rtkit-daemon.serviceConfig.LogLevelMax = "info";

      # Lower PCI latency timers, with sound cards prioritised (fewer audio gaps).
      systemd.services.pci-latency = {
        description = "Adjust latency timers for PCI peripherals";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pciLatency}/bin/pci-latency";
        };
      };
    })

    # Correct channels and transmit power for the country you're in.
    (lib.mkIf cfg.wifiRegdomain {
      hardware.wirelessRegulatoryDatabase = true;
      services.udev.extraRules = ''
        SUBSYSTEM=="ieee80211", ACTION=="add", TAG+="systemd", ENV{SYSTEMD_WANTS}+="pond-iw-set-regdomain.service"
      '';
      systemd.services.pond-iw-set-regdomain = {
        description = "Set Wireless Regulatory Domain on Timezone Change";
        after = [ "local-fs.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${iwSetRegdomain}/bin/iw-set-regdomain";
        };
      };
      systemd.paths.pond-iw-set-regdomain = {
        description = "Monitor Timezone Changes to Set Wireless Regulatory Domain";
        wantedBy = [ "multi-user.target" ];
        pathConfig = {
          PathChanged = "/etc/localtime";
          Unit = "pond-iw-set-regdomain.service";
        };
      };
    })

    (lib.mkIf cfg.systemd {
      systemd.settings.Manager = {
        DefaultTimeoutStartSec = lib.mkDefault "15s";
        DefaultTimeoutStopSec = lib.mkDefault "10s";
        DefaultLimitNOFILE = lib.mkDefault "2048:2097152";
      };
      # systemd.user.settings and services.journald.settings replaced the
      # extraConfig options in newer nixpkgs; support both.
      systemd.user =
        if options.systemd.user ? settings then
          {
            settings.Manager = {
              DefaultTimeoutStartSec = lib.mkDefault "15s";
              DefaultTimeoutStopSec = lib.mkDefault "10s";
              DefaultLimitNOFILE = lib.mkDefault "1024:1048576";
            };
          }
        else
          {
            extraConfig = ''
              DefaultTimeoutStartSec=15s
              DefaultTimeoutStopSec=10s
              DefaultLimitNOFILE=1024:1048576
            '';
          };
      services.journald =
        if options.services.journald ? settings then
          { settings.Journal.SystemMaxUse = lib.mkDefault "50M"; }
        else
          {
            extraConfig = ''
              SystemMaxUse=50M
            '';
          };
      systemd.tmpfiles.rules = [ "e /var/lib/systemd/coredump - - - 3d" ];
    })

    (lib.mkIf cfg.ananicy {
      services.ananicy = {
        enable = true;
        package = lib.mkDefault pkgs.ananicy-cpp;
        rulesProvider = lib.mkDefault pkgs.ananicy-rules-cachyos;
      };
    })

    (lib.mkIf cfg.network {
      services.resolved.enable = true;
      networking.networkmanager.dns = lib.mkIf config.networking.networkmanager.enable (
        lib.mkDefault "systemd-resolved"
      );
      services.timesyncd = {
        servers = lib.mkDefault [ "time.cloudflare.com" ];
        fallbackServers = lib.mkDefault [
          "time.google.com"
          "0.nixos.pool.ntp.org"
          "1.nixos.pool.ntp.org"
        ];
      };
    })
  ];
}
