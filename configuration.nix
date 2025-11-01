{ config, pkgs, lib, ... }:
let
  pipewire' = (pkgs.pipewire.override (lib.optionalAttrs config.services.mdevd.enable {
    enableSystemd = false;
    udev = pkgs.libudev-zero;
  })).overrideAttrs (o: {
    # https://gitlab.freedesktop.org/pipewire/pipewire/-/issues/2398#note_2967898
    patches = o.patches or [ ] ++ [ ./pipewire.patch ];
  });

  wireplumber' = pkgs.wireplumber.override (lib.optionalAttrs config.services.mdevd.enable {
    pipewire = pipewire';
  });

  aquamarine' = pkgs.aquamarine.override (lib.optionalAttrs config.services.mdevd.enable {
    libinput = libinput';
    udev = pkgs.libudev-zero;
  });

  kodi' = pkgs.kodi.override (lib.optionalAttrs config.services.mdevd.enable {
    udev = pkgs.libudev-zero;

    libcec = pkgs.libcec.override {
      udev = pkgs.libudev-zero;
    };
  });

  libinput' = (pkgs.libinput.override {
    udev = pkgs.libudev-zero;
  }).overrideAttrs (o: {
    mesonFlags = (o.mesonFlags or [ ]) ++ [
      "-Dlibwacom=false"
    ];
  });

  niri' = pkgs.niri.override (lib.optionalAttrs config.services.mdevd.enable {
    eudev = pkgs.libudev-zero;
    withSystemd = false;
    libinput = libinput';
  });

  labwc' = pkgs.labwc.override (lib.optionalAttrs config.services.mdevd.enable {
    libinput = libinput';
    wlroots_0_19 = pkgs.wlroots_0_19.override {
      libinput = libinput';
    };
  });

  sway' = pkgs.sway.override (lib.optionalAttrs config.services.mdevd.enable {
    sway-unwrapped = pkgs.sway-unwrapped.override {
      systemdSupport = false;
      libinput = libinput';

      wlroots = pkgs.wlroots.override {
        libinput = libinput';
      };
    };
  });

  hyprland' = pkgs.hyprland.override (lib.optionalAttrs config.services.mdevd.enable {
    aquamarine = aquamarine';
    libinput = libinput';
    withSystemd = false;
  });

  waybar' = (pkgs.waybar.overrideAttrs (o: {
    patches = o.patches or [ ] ++ lib.optionals config.services.mdevd.enable [
      (pkgs.fetchpatch {
        url = "https://github.com/Alexays/Waybar/commit/bef35e48fe8b38aa1cfb67bc25bf7ae42c2ffd4b.patch";
        hash = "sha256-3pSQe4JfqLDIocHRXgngVcHd6aa6gmY5gIdIVphEgrw=";
      })
    ];
  })).override (lib.optionalAttrs config.services.mdevd.enable {
    systemdSupport = false;
    udev = pkgs.libudev-zero;
  });
in
{
  imports = [
    ./hardware-configuration.nix
    ./sops
    ./pam.nix
    ./test.nix

    ./limine.nix
  ];

  providers.scheduler.backend = lib.mkForce "fcron";

  services.cron.enable = true;
  services.cron.extraArgs = [ "-s" ];
  services.cron.settings = {
    RANDOM_DELAY = 10;
  };

  services.anacron.enable = true;
  services.anacron.settings = {
    NO_MAIL_OUTPUT = 1;
  };

  programs.xfconf.enable = true;

  security.pam.environment = {
    SSH_ASKPASS.default = "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";

    # https://wiki.nixos.org/wiki/Accelerated_Video_Playback#Intel
    LIBVA_DRIVER_NAME.default = "iHD";
  };

  # TODO: grub.sh doesn't read boot.kernelParams yet
  boot.kernelParams = [
    # https://community.frame.work/t/linux-battery-life-tuning/6665/156
    "nvme.noacpi=1"
  ];

  # TODO: options for nix remote builders
  environment.etc."nix/machines".enable = true;
  environment.etc."nix/machines".text = lib.concatMapStringsSep "\n" (v: "ssh://${v}.node x86_64-linux - 20 2 benchmark,big-parallel - -") [
    "arche"
    "callisto"
    "europa"
    "helike"
    "herse"
    "kore"
    "metis"
  ];
  finit.services.nix-daemon.env = pkgs.writeText "nix-daemon.env" ''
    PATH="${lib.makeBinPath [ config.services.nix-daemon.package pkgs.util-linux config.services.openssh.package ]}:$PATH"
    CURL_CA_BUNDLE=${config.security.pki.caBundle}
  '';

  sops.validateSopsFiles = false;
  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.sshKeyPaths = [ "/var/lib/sshd/ssh_host_ed25519_key" ];

  sops.secrets."aaron/password".neededForUsers = true;
  # sops.secrets."dev0-hetz/bastion" = { };

#   providers.generator.files = {
#     ssh_config = {
#       file = pkgs.writeText "ssh_config" ''
#         Host dev0-hetz
#           HostName ${config.providers.generator.values."dev0-hetz/bastion"}
#           # IdentityFile ~/.ssh/id_ed25519
#           IdentityFile /home/aaron/.cache/tvbeat/.ssh/id_ed25519
#           Port 443
#           User aanderse
#
#         Host arche.node
#           HostName arche.node
#           ProxyJump dev0-hetz
#           # IdentityFile ~/.ssh/id_ed25519
#           IdentityFile /home/aaron/.cache/tvbeat/.ssh/id_ed25519
#           User aanderse
#       '';
#
#       path = "/etc/ssh/ssh_config";
#       mode = "0444";
#     };
#   };

  # programs.ssh.extraConfig = with config.generators; ''
  #   Host dev0-hetz
  #     HostName ${values."dev0-hetz/bastion"}
  # '';

  networking.hostName = "framework";

  finit.runlevel = 3;

  finit.tasks.charge-limit.command = "${lib.getExe pkgs.framework-tool} --charge-limit 80";
  finit.tasks.nftables.command = "${lib.getExe pkgs.nftables} -f /etc/nftables.rules";

  finit.services.wifid = {
    command = pkgs.callPackage ./wifid/package.nix { };
    log = true;
  };


  # TODO: create a base system profile
  services.atd.enable = true;
  services.chrony.enable = true;
  services.fcron.enable = true;
  services.dbus.enable = true;
  services.fwupd.enable = true;
  services.fwupd.debug = false;
  services.iwd.enable = true;
  services.nix-daemon.enable = true;
  services.nix-daemon.nrBuildUsers = 32;
  services.nix-daemon.settings = {
    # experimental-features = [ "flakes" "nix-command" ];
    experimental-features = [ "nix-command" "pipe-operators" ];
    download-buffer-size = 524288000;
    fallback = true;
    log-lines = 25;
    warn-dirty = false;
    builders-use-substitutes = true;
    build-dir = "/var/tmp";

    substituters = [ "https://jovian-nixos.cachix.org" ];
    trusted-public-keys = [ "jovian-nixos.cachix.org-1:mAWLjAxLNlfxAnozUjOqGj4AxQwCl7MXwOfu7msVlAo=" ];
    trusted-users = [ "root" "@wheel" ];
  };
  services.openssh.enable = false;
  services.dropbear.enable = true;
  finit.services.dropbear.conditions = [ "usr/with-an-e" ];
  services.sysklogd.enable = true;
  # services.udev.enable = true;
  services.mdevd.enable = true;
  services.mdevd.nlgroups = 4;
  services.mdevd.debug = true;

  # .* 0:0 660 @${pkgs.finit}/libexec/finit/logit -s -t mdevd "event=$ACTION dev=$MDEV subsystem=$SUBSYSTEM path=$DEVPATH devtype=$DEVTYPE modalias=$MODALIAS major=$MAJOR minor=$MINOR"
  # TODO: shouldn't this just be included by default?
  services.mdevd.hotplugRules = lib.mkMerge [
    (lib.mkAfter ''
      SUBSYSTEM=input;.* root:input 660
      SUBSYSTEM=sound;.* root:audio 660
    '')

    ''
      grsec       root:root 660
      kmem        root:root 640
      mem         root:root 640
      port        root:root 640
      console     root:tty 600 @chmod 600 $MDEV
      card[0-9]   root:video 660 =dri/

      # alsa sound devices and audio stuff
      pcm.*       root:audio 0660 =snd/
      control.*   root:audio 0660 =snd/
      midi.*      root:audio 0660 =snd/
      seq         root:audio 0660 =snd/
      timer       root:audio 0660 =snd/

      adsp        root:audio 0660 >sound/
      audio       root:audio 0660 >sound/
      dsp         root:audio 0660 >sound/
      mixer       root:audio 0660 >sound/
      sequencer.* root:audio 0660 >sound/

      event[0-9]+ root:input 660 =input/
      mice        root:input 660 =input/
      mouse[0-9]+ root:input 660 =input/

      rfkill      root:${config.services.seatd.group} 660
    ''
  ];
  services.polkit.enable = true;

  programs.openresolv.enable = true;
  programs.openresolv.package = pkgs.openresolv.overrideAttrs (_: {
    # TODO: could potentially make 'RESTARTCMD' an overridable option for the package
    configurePhase = ''
      cat > config.mk <<EOF
      PREFIX=$out
      SYSCONFDIR=/etc
      SBINDIR=$out/sbin
      LIBEXECDIR=$out/libexec/resolvconf
      VARDIR=/run/resolvconf
      MANDIR=$out/share/man
      RESTARTCMD="/run/current-system/sw/bin/initctl restart \\\\\$\$1"
      EOF
    '';
  });
  programs.bash.enable = true;
  programs.fish.enable = true;
  programs.virtualbox.enable = true;
  programs.brightnessctl.enable = true;

  # https://forums.virtualbox.org/viewtopic.php?p=556540#p556540
  environment.etc."modprobe.d/blacklist-kvm.conf".text = ''
    # kernel 6.12 and later ship with kvm enabled by default, which breaks vbox
    blacklist kvm
    blacklist kvm_intel
  '';

  # TODO: create graphical desktop profiles
  services.rtkit.enable = true;
  services.bluetooth.enable = true;
  services.seatd.enable = true;
  services.ddccontrol.enable = true;
  programs.regreet.enable = true;
  programs.regreet.compositor = {
    package = pkgs.cage.override {
      wlroots_0_19 = pkgs.wlroots_0_19.override {
        libinput = libinput';

        enableXWayland = false;
      };
    };
    extraArgs = [ "-s" "-m" "last" ];
    environment = {
      XKB_DEFAULT_LAYOUT = "us";
      XKB_DEFAULT_VARIANT = "dvorak";
    };
  };
  programs.niri.enable = true;
  programs.niri.package = niri';
  programs.hyprlock.enable = true;
  programs.hyprland.enable = true;
  programs.hyprland.package = hyprland';
  programs.sway.enable = true;
  programs.sway.package = sway';
  programs.labwc.enable = true;
  programs.labwc.package = labwc';
  programs.gnome-keyring.enable = true;
  programs.seahorse.enable = true;
  programs.xwayland-satellite.enable = true;

  services.system76-scheduler.enable = true;
  services.system76-scheduler.configFile = pkgs.writeText "config.kdl" ''
    version "2.0"

    process-scheduler enable=true {
      refresh-rate 60
      execsnoop true

      assignments {
        // nix-daemon io=(best-effort)4 sched="batch" {
        nix-daemon io=(idle)4 sched="idle" {
          include cgroup="/system/nix-daemon"
        }
      }
    }
  '';

  finit.services.nix-daemon.cgroup.settings = {
    "cpu.max" = "800000 100000";
    "cpu.weight" = 80;
  };

  # misc
  services.fprintd.enable = true;
  services.fstrim.enable = true;
  services.zfs.autoSnapshot.enable = true;
  services.zfs.autoSnapshot.flags = "-k -p --utc";
  services.zfs.autoScrub.enable = true;
  services.tzupdate.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.zerotierone.enable = true;
  services.incus.enable = true;
  finit.services.incusd.manual = true;

  # NOTE: https://wiki.alpinelinux.org/wiki/Polkit#Using_polkit_with_seatd
  services.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      // allow user "aaron" to utilize the fingerprint reader
      // not great for security but acceptible given this is a single user laptop... i guess
      if (subject.user == "aaron" && action.id.startsWith("net.reactivated.fprint.device.")) {
        return polkit.Result.YES;
      }

      if (subject.isInGroup("${config.services.seatd.group}") && action.id.startsWith("org.freedesktop.RealtimeKit1.")) {
        return polkit.Result.YES;
      }

      if (subject.isInGroup("${config.services.seatd.group}") && action.id.startsWith("org.freedesktop.UPower.PowerProfiles.")) {
        return polkit.Result.YES;
      }
    });
  '';

  security.pki.certificates = [
    # homelab certificate authority
    ''
      -----BEGIN CERTIFICATE-----
      MIIBoTCCAUmgAwIBAgIQe2OFt43uF4Sb5jDGhPnyhDAKBggqhkjOPQQDAjAwMRIw
      EAYDVQQKEwlzbWFsbHN0ZXAxGjAYBgNVBAMTEXNtYWxsc3RlcCBSb290IENBMB4X
      DTI0MDgxMDE2MzIzOFoXDTM0MDgwODE2MzIzOFowMDESMBAGA1UEChMJc21hbGxz
      dGVwMRowGAYDVQQDExFzbWFsbHN0ZXAgUm9vdCBDQTBZMBMGByqGSM49AgEGCCqG
      SM49AwEHA0IABJDOXimoUROCIChjTjF+ZUBBVJdRR2Tlf14bpaLXLfqSJsuP3KO9
      tCLF0qp+iwksOfZur7oIw/Fq1i+zt592J/ajRTBDMA4GA1UdDwEB/wQEAwIBBjAS
      BgNVHRMBAf8ECDAGAQH/AgEBMB0GA1UdDgQWBBSXX+tNn8NffSeoabfNBwenT2Nh
      3DAKBggqhkjOPQQDAgNGADBDAiABz4DuLfUnP4O0rpjawvqkzV42jG2IfFPpKGFn
      n4IkxQIfaUGmo6r05finZYU2zKbmUsfL5BrQ8XBcOcFlG6UQkQ==
      -----END CERTIFICATE-----
    ''

    # local caddy
    ''
      -----BEGIN CERTIFICATE-----
      MIIBozCCAUqgAwIBAgIRANr2xLr5ZiKvfJdzJgwaR2gwCgYIKoZIzj0EAwIwMDEu
      MCwGA1UEAxMlQ2FkZHkgTG9jYWwgQXV0aG9yaXR5IC0gMjAyNSBFQ0MgUm9vdDAe
      Fw0yNTA3MjkxNjI3MjlaFw0zNTA2MDcxNjI3MjlaMDAxLjAsBgNVBAMTJUNhZGR5
      IExvY2FsIEF1dGhvcml0eSAtIDIwMjUgRUNDIFJvb3QwWTATBgcqhkjOPQIBBggq
      hkjOPQMBBwNCAAQ+87jFZAi3YtgPTi6ttp0jSboslaUq1AsQHZ1yOYcTLOoVoTrF
      NZjvu2dMFjImBY8M0093ySHyhTnyKm+jGf6io0UwQzAOBgNVHQ8BAf8EBAMCAQYw
      EgYDVR0TAQH/BAgwBgEB/wIBATAdBgNVHQ4EFgQUK7hD+/RQrUzT8agu9K0hkmsj
      xcQwCgYIKoZIzj0EAwIDRwAwRAIgBp8H/IGb7DtKzCK8/y66L+uqJgOyKqFE6l4W
      SfgIeDMCIHjVvjsyFh3Nhero7LwiB0kZbszT5stt9Hb9pt35nC58
      -----END CERTIFICATE-----
    ''
  ];

  xdg.portal.portals = [
    pkgs.xdg-desktop-portal-hyprland
    pkgs.xdg-desktop-portal-wlr
    pkgs.xdg-desktop-portal-gtk
  ];

  services.dbus.packages = [
    pkgs.dconf
  ];

  fonts.fontconfig.enable = true;

  fonts.enableDefaultPackages = true;
  fonts.packages = with pkgs; [
    fira-code
    fira-code-symbols
    font-awesome
    liberation_ttf
    mplus-outline-fonts.githubRelease
    nerd-fonts._0xproto
    nerd-fonts.droid-sans-mono
    noto-fonts
    noto-fonts-color-emoji
    proggyfonts
  ];

  # TODO: move to services.sysklogd module
  environment.etc."syslog.d/rotate.conf".text = ''
    rotate_size  1M
    rotate_count 5
  '';

  providers.privileges.rules = [
    { command = "/run/current-system/sw/bin/poweroff";
      users = [ "aaron" ];
      requirePassword = false;
    }
    { command = "/run/current-system/sw/bin/reboot";
      users = [ "aaron" ];
      requirePassword = false;
    }
  ] ++ lib.optionals config.services.mdevd.enable [
    {
      command = "/run/current-system/sw/bin/pm-suspend";
      groups = [ config.services.seatd.group] ;
      requirePassword = false;
    }
  ];

  services.udev.packages = [
    config.services.udev.package
  ];

  hardware.firmware = with pkgs; [
    linux-firmware
    intel2200BGFirmware
    rtl8192su-firmware
    rt5677-firmware
    rtl8761b-firmware
    zd1211fw
    alsa-firmware
    sof-firmware
    libreelec-dvb-firmware

    broadcom-bt-firmware
    b43Firmware_5_1_138
    b43Firmware_6_30_163_46
    xow_dongle-firmware

    pkgs.wireless-regdb
  ];

  users.users.aaron = {
    isNormalUser = true;
    shell = pkgs.fish;
    passwordFile = config.sops.secrets."aaron/password".path;
    group = "users";
    home = "/home/aaron";
    createHome =  true;

    extraGroups = [
      config.hardware.i2c.group
      config.services.seatd.group
      "audio"
      "incus-admin"
      "input"
      "vboxusers"
      "video"
      "wheel"
    ];
  };

  environment.pathsToLink = [
    # TODO: xdg.icon module
    "/share/icons"
    "/share/pixmaps"
  ];

  environment.systemPackages = [
    pkgs.alacritty
    pkgs.bzmenu
    pkgs.ddcutil
    pkgs.dex
    pkgs.ghostty
    pkgs.iwmenu
    pkgs.kanshi
    pkgs.mako
    pkgs.musikcube
    pkgs.playerctl
    pkgs.pwmenu
    pkgs.swaybg
    pkgs.swayidle
    pkgs.walker pkgs.fuzzel
    waybar'

    pkgs.direnv
    pkgs.dnsutils
    pkgs.git
    pkgs.glow
    pkgs.htop
    pkgs.lnav
    pkgs.jq
    pkgs.lon
    pkgs.mailutils
    pkgs.man
    pkgs.micro
    pkgs.nano
    pkgs.ncdu
    pkgs.nix-diff
    pkgs.nix-output-monitor
    pkgs.nix-top
    pkgs.nixd
    pkgs.sops
    pkgs.ssh-to-age
    pkgs.tree
    pkgs.wget
    pkgs.yazi

    (pkgs.chromium.override {
      commandLineArgs = [
        "--enable-features=AcceleratedVideoEncoder"
        "--ignore-gpu-blocklist"
        "--enable-zero-copy"
      ];
    })
    pkgs.firefox
    pkgs.qbittorrent
    pkgs.steam
    pkgs.xarchiver

    # pkgs.lite-xl # broken recently
    pkgs.marp-cli
    pkgs.tdf
    (pkgs.vscode-with-extensions.override {
      vscodeExtensions = with pkgs.vscode-extensions; [
        Google.gemini-cli-vscode-ide-companion
        mkhl.direnv
        ms-python.python
        rust-lang.rust-analyzer
      ];
    })
    pkgs.zed-editor

    pkgs.discord
    (pkgs.element-desktop.override { commandLineArgs = "--password-store=gnome-libsecret"; })
    pkgs.joplin-desktop
    (pkgs.pidgin.override {
      plugins = with pkgs.pidginPackages; [
        pidgin-otr
        pidgin-carbons
        pidgin-osd
        pidgin-window-merge
        purple-plugin-pack
      ];
    })
    pkgs.quasselClient
    (pkgs.signal-desktop.override { commandLineArgs = "--password-store=gnome-libsecret"; })
    pkgs.slack

    pkgs.bluetui
    pkgs.framework-tool
    pkgs.impala
    pkgs.libnotify
    pkgs.mixxc
    pkgs.wiremix
    pipewire'
    pkgs.pmutils
    wireplumber'
    pkgs.wl-clipboard
    pkgs.xdg-utils

    pkgs.iproute2
    pkgs.iputils
    pkgs.nettools
    pkgs.nftables


    pkgs.bustle
    pkgs.d-spy
    pkgs.dconf-editor
    libinput'

    pkgs.perl
    pkgs.strace
    pkgs.tcl-9_0

    pkgs.nix-tree

    pkgs.hicolor-icon-theme # TODO: xdg.icon module
    pkgs.catppuccin-cursors.mochaLight

    pkgs.dconf

    pkgs.util-linux
    pkgs.e2fsprogs
    pkgs.kbd

    # TODO: grub module
    pkgs.efibootmgr
    pkgs.grub2_efi


    pkgs.rink
    pkgs.libqalculate

    pkgs.imv # TODO: set as default image viewer

    (kodi'.withPackages (p: [ p.jellyfin p.jellycon p.a4ksubtitles ]))

    # TODO: add `programs.ssh.*` options
    pkgs.openssh
  ];

  hardware.console.keyMap = "us";
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  # https://wiki.nixos.org/wiki/Accelerated_Video_Playback#Intel
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];
  hardware.graphics.extraPackages32 = [ pkgs.pkgsi686Linux.intel-media-driver ];

  # programs.kodi.enable = true;
  # programs.kodi.desktopSession.enable = true;
  # programs.kodi.settings = {
  #   # ...
  # };
}
