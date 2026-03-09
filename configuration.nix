{
  config,
  pkgs,
  lib,
  ...
}:
let
  pipewire' =
    (pkgs.pipewire.override (
      lib.optionalAttrs config.services.mdevd.enable {
        enableSystemd = false;
        udev = pkgs.libudev-zero;
      }
    )).overrideAttrs
      (o: {
        # https://gitlab.freedesktop.org/pipewire/pipewire/-/issues/2398#note_2967898
        patches = o.patches or [ ] ++ lib.optionals config.services.mdevd.enable [ ./pipewire.patch ];
      });

  wireplumber' = pkgs.wireplumber.override (
    lib.optionalAttrs config.services.mdevd.enable {
      pipewire = pipewire';
    }
  );

  kodi' = pkgs.kodi-wayland.override (
    lib.optionalAttrs config.services.mdevd.enable {
      udev = pkgs.libudev-zero;

      libcec = pkgs.libcec.override {
        udev = pkgs.libudev-zero;
      };
    }
  );
in
{
  imports = [
    ./hardware-configuration.nix
    ./sops
    ./pam.nix
    # ./podman.nix
  ];

  # experiment with network namespace support for finix
  # finit.ttys.tty1.extraConfig = "netns:zerotier";
  # finit.services.zerotierone.extraConfig = "netns:zerotier";
  # boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  # finit.package = pkgs.finit.overrideAttrs (finalAttrs: {
  #   patches = finalAttrs.patches or [ ] ++ [ /home/aaron/code/finit/netns-support.patch ];
  # });

  # wip - cups module
  # services.cups.enable = true;

  # experiment with user level service manager... dinit
  # finit.services.dinit-user-spawn = {
  #   command = pkgs.callPackage ./dinit-user-spawn.nix { };
  #   runlevels = "234";
  #   conditions = "service/syslogd/ready";
  #   cgroup.name = "user";
  #   log = true;
  # };

  specialisation.udev = {
    services.mdevd.enable = lib.mkForce false;
    services.udev.enable = lib.mkForce true;
  };

  specialisation.elogind = {
    services.mdevd.enable = lib.mkForce false;
    services.udev.enable = lib.mkForce true;

    services.elogind.enable = lib.mkForce true;
    services.seatd.enable = lib.mkForce false;
  };

  boot.loader.efi.canTouchEfiVariables = true;

  programs.limine.enable = true;
  programs.limine.settings.editor_enabled = true;

  programs.noisetorch.enable = true;
  programs.pmount.enable = true;

  programs.dma.enable = true;
  programs.dma.settings = {
    SMARTHOST = "smtp.fastmail.com";
    PORT = 465;
    MASQUERADE = "aaron@fosslib.net";
    SECURETRANSFER = true;
    VERIFYCERT = true;
    AUTHPATH = "/etc/dma/auth.conf";
  };

  security.pam.environment = {
    SSH_ASKPASS.default = "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";

    # https://wiki.nixos.org/wiki/Accelerated_Video_Playback#Intel
    LIBVA_DRIVER_NAME.default = "iHD";
  };

  # TODO: some sort of option i guess
  environment.etc."security/limits.conf".text = ''
    @audio   -   rtprio     95
    @audio   -   nice       -19
    @audio   -   memlock    4194304
  '';

  boot.kernelParams = [
    "loglevel=1"

    # https://community.frame.work/t/linux-battery-life-tuning/6665/156
    "nvme.noacpi=1"
  ];

  # TODO: options for nix remote builders
  environment.etc."nix/machines".enable = false;
  environment.etc."nix/machines".text =
    lib.concatMapStringsSep "\n" (v: "ssh://${v}.node x86_64-linux - 20 2 benchmark,big-parallel - -")
      [
        "arche"
        "callisto"
        "europa"
        "helike"
        "herse"
        "kore"
        # "metis"
      ];

  finit.services.nix-daemon.environment.CURL_CA_BUNDLE = config.security.pki.caBundle;
  finit.services.nix-daemon.path = [
    config.services.nix-daemon.package
    pkgs.util-linux
    config.services.openssh.package
  ];

  sops.validateSopsFiles = false;
  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.sshKeyPaths = [ "/var/lib/sshd/ssh_host_ed25519_key" ];

  sops.secrets."aaron/password".neededForUsers = true;

  networking.hostName = "framework";
  networking.hostId = "a3c6de71";

  networking.hosts = {
    "linode" = [ "172.23.7.207" ];
    "techiem2" = [ "172.23.193.205" ];
  };

  finit.runlevel = 3;

  finit.tasks.charge-limit = {
    conditions = "service/syslogd/ready";
    command = "${lib.getExe pkgs.framework-tool} --charge-limit 80";
    log = true;
  };

  finit.services.wifid = {
    command = pkgs.callPackage ./wifid/package.nix { };
    log = true;
    nohup = true;
    path = [ config.finit.package ];
  };

  # TODO: create a base system profile
  services.atd.enable = true;
  services.chrony.enable = true;
  services.fcron.enable = true;
  services.fcron.systab = lib.mkBefore [ "MAILTO=aaron@fosslib.net" ];
  services.dbus.enable = true;
  services.earlyoom.enable = true;
  services.earlyoom.extraArgs = [
    "-r"
    "3600"
  ];
  services.fwupd.enable = true;
  services.fwupd.debug = false;
  services.illum.enable = true;
  services.iwd.enable = true;
  services.nix-daemon.enable = true;
  services.nix-daemon.nrBuildUsers = 32;
  services.nix-daemon.settings = {
    experimental-features = [
      "nix-command"
      "pipe-operators"
    ];
    download-buffer-size = 524288000;
    fallback = true;
    log-lines = 25;
    warn-dirty = false;
    builders-use-substitutes = true;
    build-dir = "/var/tmp";

    trusted-users = [
      "root"
      "@wheel"
    ];
  };
  services.openssh.enable = false;
  services.dropbear.enable = true;
  finit.services.dropbear.conditions = [ "usr/with-an-e" ];
  services.sysklogd.enable = true;
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
  services.nftables.enable = true;
  services.nftables.configFile = pkgs.writeText "nftables.conf" ''
    # https://wiki.nftables.org/wiki-nftables/index.php/Quick_reference-nftables_in_10_minutes#Simple_IP/IPv6_Firewall

    flush ruleset

    table firewall {
      chain incoming {
        type filter hook input priority 0; policy drop;

        # established/related connections
        ct state established,related accept

        # loopback interface
        iifname lo accept

        # icmp
        icmp type echo-request accept

        # open tcp ports: sshd (22), http-alt (8080)
        tcp dport { 22, 8080 } accept
      }
    }

    table ip6 firewall {
      chain incoming {
        type filter hook input priority 0; policy drop;

        # established/related connections
        ct state established,related accept

        # invalid connections
        ct state invalid drop

        # loopback interface
        iifname lo accept

        # icmp
        # routers may also want: mld-listener-query, nd-router-solicit
        icmpv6 type { echo-request, nd-neighbor-solicit } accept

        # open tcp ports: sshd (22), http-alt (8080)
        tcp dport { 22, 8080 } accept
      }
    }
  '';
  services.polkit.enable = true;

  programs.resolvconf.enable = true;
  programs.resolvconf.package = pkgs.openresolv.overrideAttrs (_: {
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
  programs.sudo.enable = true;
  programs.zzz.enable = true;

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
    extraArgs = [
      "-d"
      "-s"
      "-m"
      "last"
    ];
    environment = {
      XKB_DEFAULT_LAYOUT = "us";
      XKB_DEFAULT_VARIANT = "dvorak";
    };
  };
  programs.niri.enable = true;
  programs.hyprlock.enable = true;
  programs.hyprland.enable = true;
  programs.sway.enable = true;
  programs.labwc.enable = true;
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
        // Keep nix-daemon deprioritized as a backup
        nix-daemon io=(idle)4 sched="idle" nice=19 {
          include cgroup="/system/nix-daemon"
        }
      }
    }
  '';

  finit.services.nix-daemon.cgroup.settings = {
    "cpu.max" = "800000 100000";
    "cpu.weight" = 50;
    "io.weight" = 50;
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
  finit.services.incusd = lib.mkIf config.services.incus.enable {
    manual = true;
  };

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
    pkgs.xdg-desktop-portal-gnome
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
    {
      command = "/run/current-system/sw/bin/poweroff";
      users = [ "aaron" ];
      requirePassword = false;
    }
    {
      command = "/run/current-system/sw/bin/reboot";
      users = [ "aaron" ];
      requirePassword = false;
    }
  ]
  ++ lib.optionals config.services.mdevd.enable [
    {
      command = "/run/current-system/sw/bin/pm-suspend";
      groups = [ config.services.seatd.group ];
      requirePassword = false;
    }
    {
      command = "/run/current-system/sw/bin/zzz";
      groups = [ config.services.seatd.group ];
      requirePassword = false;
    }
    {
      command = "/run/current-system/sw/bin/ZZZ";
      groups = [ config.services.seatd.group ];
      requirePassword = false;
    }
  ];

  services.udev.packages = [
    config.services.udev.package
  ];

  hardware.firmware = with pkgs; [
    linux-firmware
    sof-firmware
    wireless-regdb
  ];

  users.users.root.passwordFile = config.sops.secrets."aaron/password".path;
  users.users.aaron = {
    isNormalUser = true;
    shell = pkgs.fish;
    passwordFile = config.sops.secrets."aaron/password".path;
    group = "users";
    home = "/home/aaron";
    createHome = true;

    extraGroups = [
      config.hardware.i2c.group
      config.services.seatd.group
      "audio"
      "incus-admin"
      "input"
      "kvm"
      "vboxusers"
      "video"
      "wheel"
    ];
  };

  environment.etc.subuid.mode = "0444";
  environment.etc.subgid.mode = "0444";

  environment.etc.subuid.text = "aaron:100000:65536";
  environment.etc.subgid.text = "aaron:100000:65536";

  users.users.test = {
    isNormalUser = true;
    shell = pkgs.fish;
    passwordFile = config.sops.secrets."aaron/password".path;
    group = "users";
    home = "/home/test";
    createHome = true;

    extraGroups = [
      config.hardware.i2c.group
      config.services.seatd.group
      "audio"
      "input"
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
    pkgs.slurp # needed for xdg-desktop-portal-luminous?
    pkgs.starship # TODO: move to personal config
    (pkgs.noctalia-shell.overrideAttrs (oldAttrs: {
      patches = (oldAttrs.patches or [ ]) ++ [
        ./noctalia-shell-distro-logo.patch
      ];
    })) # TODO: move to personal config??
    pkgs.mob # TODO: move to personal config
    pkgs.fresh-editor # TODO: move to personal config
    pkgs.pamtester # temporary, testing
    pkgs.asciinema # TODO: move to personal config
    pkgs.syncthing # TODO: move to personal config?
    pkgs.claude-code # TODO: move to personal config
    pkgs.fastfetch
    pkgs.nixos-rebuild-ng

    pkgs.ddcutil
    pkgs.dex
    pkgs.ghostty
    pkgs.kanshi
    pkgs.musikcube
    pkgs.swayidle

    pkgs.mailutils
    pkgs.man
    pkgs.nano
    # (most of) these tools can/should be moved into a local profile - but kept in sync with <nixpkgs> ideally
    pkgs.delta
    pkgs.direnv
    pkgs.dnsutils
    pkgs.git
    pkgs.glow
    pkgs.htop
    pkgs.lnav
    pkgs.jq
    pkgs.nix-prefetch-git
    pkgs.micro
    pkgs.ncdu
    pkgs.nix-diff
    pkgs.nix-output-monitor
    pkgs.nix-top
    pkgs.nix-tree
    pkgs.nixd
    pkgs.nixfmt
    pkgs.python3Packages.python-lsp-server
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
    pkgs.steam.run
    pkgs.xarchiver

    pkgs.marp-cli
    pkgs.tdf
    (pkgs.vscode-with-extensions.override {
      vscodeExtensions = with pkgs.vscode-extensions; [
        # anthropic.claude-code
        bbenoist.nix
        jnoortheen.nix-ide
        mkhl.direnv
        ms-python.python
        ms-vscode-remote.remote-ssh
        rust-lang.rust-analyzer
      ]
      # ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
      #   {
      #     name = "claude-code";
      #     publisher = "anthropic";
      #     version = "2.0.50";
      #     hash = "sha256-Pd4rRLS613/zSn8Pvr/cozaIAqrG06lmUC6IxHm97XQ=";
      #   }
      # ]
      ;
    })

    pkgs.discord
    (pkgs.element-desktop.override { commandLineArgs = "--password-store=gnome-libsecret"; })
    pkgs.joplin-desktop
    (pkgs.pidgin.override {
      plugins = with pkgs.pidginPackages; [
        pidgin-otr
        pidgin-carbons
        pidgin-osd
        pidgin-window-merge
        # purple-plugin-pack
      ];
    })
    pkgs.quasselClient
    (pkgs.signal-desktop.override { commandLineArgs = "--password-store=gnome-libsecret"; })
    pkgs.slack

    pkgs.bluetui
    pkgs.framework-tool
    pkgs.impala
    pkgs.libnotify
    pkgs.wiremix
    pipewire'
    pkgs.pmutils # isn't zzz doing this now?
    wireplumber'
    pkgs.wl-clipboard
    pkgs.xdg-utils

    pkgs.iproute2
    pkgs.iputils
    pkgs.nettools

    pkgs.bustle
    pkgs.d-spy
    pkgs.dconf-editor

    pkgs.perl
    pkgs.strace

    pkgs.hicolor-icon-theme # TODO: xdg.icon module
    pkgs.catppuccin-cursors.mochaLight

    pkgs.dconf

    pkgs.util-linux
    pkgs.e2fsprogs
    pkgs.kbd

    pkgs.imv # TODO: set as default image viewer

    (kodi'.withPackages (p: [
      p.a4ksubtitles
      p.jellycon
      p.jellyfin
      p.steam-library
    ]))

    # TODO: add `programs.ssh.*` options
    pkgs.openssh
  ];

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
