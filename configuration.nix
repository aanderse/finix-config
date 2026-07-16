{
  modules,
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = with modules; [
    ddccontrol
    dinit
    dma
    dropbear
    fish
    flatpak
    flirc
    fprintd
    fstrim
    gnome-keyring
    gvfs
    hyprland
    hyprlock
    illum
    incus
    keyd
    labwc
    laptop
    lxqt
    mangowc
    micro
    niri
    noisetorch
    pmount
    seahorse
    sway
    thermald
    # turnstile
    tzupdate
    virtualbox
    xwayland-satellite
    zerotierone
    zfs
  ];

  profiles.laptop.enable = true;
  profiles.laptop.hardwareSupport = "minimal";

  # services.turnstile.enable = true;
  # services.turnstile.settings = {
  #   debug = true;
  #   manage_rundir = true;
  # };

  dinit.user.services.boot = {
    type = "internal";

    waits-for = [ "caddy" ];
  };

  dinit.user.services.caddy = {
    type = "process";
    command = "${pkgs.caddy}/bin/caddy file-server --root /tmp --listen 127.0.0.1:8080 --browse";
    restart = "on-failure";
    smooth-recovery = true;
    logfile = "/home/aaron/caddy.log";
  };

  #environment.binsh = "${pkgs.dash}/bin/dash";
  #programs.coreutils.package = pkgs.uutils-coreutils-noprefix;

  finit.package = pkgs.finit.overrideAttrs (o: {
    version = "5.0";
    src = pkgs.fetchFromGitHub {
      owner = "finit-project";
      repo = "finit";
      rev = "ad8ed05d64a4e274e39ac2d061fe8c3aa8a87c22";
      sha256 = "sha256-SJTnrcgRx/M07pOQAnm+LeiXSq9YGCON2yHLaKCMyJw=";
    };

    buildInputs = o.buildInputs ++ [ pkgs.util-linuxMinimal.dev ];

    postPatch = (o.postPatch or "") + ''
      substituteInPlace keventd/uevent.c \
        --replace-fail '"/sbin/modprobe", "modprobe"' '"${pkgs.kmod}/bin/modprobe", "modprobe"' \
        --replace-fail '"/usr/lib/firmware/' '"/run/current-system/firmware/lib/firmware/'

      substituteInPlace keventd/builtin.c \
        --replace-fail  '"/lib/udev/hwdb.d"' '"/run/current-system/sw/lib/udev/hwdb.d"' \
        --replace-fail  '"/usr/share/hwdata/usb.ids"' '"${pkgs.hwdata}/share/hwdata/usb.ids"'
    '';
  });

  # security.wrappers.X.enable = lib.mkForce false;
  # programs.xorg.enable = true;
  # programs.openbox.enable = true;
  # programs.lxqt.xsession.enable = true;

  specialisation.gardendevd = {
    profiles.laptop.hardwareSupport = lib.mkForce "standard";

    # finit.services.keventd.command = "${config.finit.package}/libexec/finit/keventd -p";
  };

  programs.limine.settings = {
    interface_resolution = "2256x1504";
    wallpaper = [ ./limine-wallpaper.png ];
    wallpaper_style = "stretched";
    backdrop = "16181d";
    term_background = "c0161818";
    term_foreground = "dcdee4";
    term_background_bright = "d31f30";
    term_foreground_bright = "ffffff";
    term_palette = "16181d;d31f30;7d7d7d;de3040;3a3f4b;e84050;9aa0ac;dcdee4";
    term_palette_bright = "2a2d35;e84050;9aa0ac;e84050;5a6070;f06070;c0c4cc;ffffff";
    term_margin = 24;
    term_margin_gradient = 24;
    interface_branding = "finix";
    interface_branding_colour = "e84050";
    interface_help_colour = "7d7d7d";
    interface_help_colour_bright = "dcdee4";
    interface_help_hidden = false;
  };

  boot.initrd.emergencyAccess = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # hmmm...
  finit.services.dropbear.conditions = [ "usr/with-an-e" ];
  finit.services.cups.conditions = [ "usr/with-an-e" ];

  security.pam.environment = {
    # https://wiki.nixos.org/wiki/Accelerated_Video_Playback#Intel
    LIBVA_DRIVER_NAME.default = "iHD";
  };

  boot.kernelParams = [
    # "plymouth.force-scale=1"

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

  finit.services.nix-daemon.path = [
    config.services.nix-daemon.package
    pkgs.util-linux
    config.services.openssh.package or pkgs.openssh
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

  finit.tasks.charge-limit = {
    conditions = "service/syslogd/ready";
    command = "${lib.getExe pkgs.framework-tool} --charge-limit 80";
    log = true;
  };

  finit.services.wifid = {
    enable = config.services.iwd.enable;
    command = pkgs.callPackage ./wifid/package.nix { };
    log = true;
    nohup = true;
    path = [ config.finit.package ];
  };

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

  # https://forums.virtualbox.org/viewtopic.php?p=556540#p556540
  environment.etc."modprobe.d/blacklist-kvm.conf".text = ''
    # kernel 6.12 and later ship with kvm enabled by default, which breaks vbox
    blacklist kvm
    blacklist kvm_intel
  '';

  programs.dma.enable = true;
  programs.dma.settings = {
    SMARTHOST = "smtp.fastmail.com";
    PORT = 465;
    MASQUERADE = "aaron@fosslib.net";
    SECURETRANSFER = true;
    VERIFYCERT = true;
    AUTHPATH = "/etc/dma/auth.conf";
  };
  programs.fish.enable = true;
  programs.hyprland.enable = true;
  programs.hyprlock.enable = true;
  programs.labwc.enable = true;
  programs.lxqt.enable = true;
  programs.gnome-keyring.enable = true;
  programs.mango.enable = true;
  programs.micro.enable = true;
  programs.micro.defaultEditor = true;
  programs.nano.enable = true;
  programs.nano.defaultEditor = false;
  programs.niri.enable = true;
  programs.noisetorch.enable = true;
  #programs.plasma.enable = true;
  programs.plymouth.enable = lib.mkForce false;
  programs.plymouth.settings = {
    Daemon = {
      DeviceScale = 1;
    };
  };
  programs.pmount.enable = true;
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
  programs.regreet.settings = {
    GTK = {
      application_prefer_dark_theme = true;
    };
  };
  programs.seahorse.enable = true;
  programs.sway.enable = true;
  programs.virtualbox.enable = true;
  programs.xwayland-satellite.enable = true;

  services.cups.enable = true;
  services.cups.package = pkgs.cups.override { enableSystemd = false; };
  services.cups.drivers = [ pkgs.brlaser ];
  services.ddccontrol.enable = true;
  services.dropbear.enable = true;
  services.fcron.systab = lib.mkBefore [ "MAILTO=aaron@fosslib.net" ]; # TODO: fcron environment variables...
  services.flatpak.enable = true;
  services.flatpak.extraGroups = lib.optionals config.services.seatd.enable [
    config.services.seatd.group
  ];
  services.fprintd.enable = true;
  services.fprintd.extraGroups = lib.optionals config.services.seatd.enable [
    config.services.seatd.group
  ];
  services.fstrim.enable = true;
  services.sysklogd.enable = true;
  services.sysklogd.extraConfig = ''
    user.*                          -/var/log/user.log

    rotate_size  1M
    rotate_count 5
  '';
  services.gvfs.enable = true;
  services.illum.enable = true; # TODO: is this needed?
  services.iwd.enable = true;
  services.networkmanager.enable = false;
  services.keyd.enable = true;
  services.keyd.keyboards = {
    default = {
      ids = [ "*" ];
      settings = {
        main = {
          # capslock = "esc";
        };
      };
    };
  };
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
    # build-dir = "/var/tmp";

    trusted-users = [
      "root"
      "@wheel"
    ];
  };
  services.thermald.enable = true;
  services.tzupdate.enable = true;
  services.zerotierone.enable = true;
  services.zfs.autoSnapshot.enable = true;
  services.zfs.autoSnapshot.flags = "-k -p --utc";
  services.zfs.autoScrub.enable = true;

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
  ];

  xdg.portal.portals = [
    pkgs.xdg-desktop-portal-gnome
    pkgs.xdg-desktop-portal-gtk
  ];

  services.dbus.packages = [
    pkgs.dconf

    pkgs.xfconf
    pkgs.thunar
  ];

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

  users.users.root.passwordFile = config.sops.secrets."aaron/password".path;
  users.users.aaron = {
    isNormalUser = true;
    shell = pkgs.fish;
    passwordFile = config.sops.secrets."aaron/password".path;

    extraGroups = [
      config.hardware.i2c.group
      config.hardware.uinput.group
      config.services.seatd.group

      "audio"
      # "gamemode"
      "incus-admin"
      "input"
      "keyd"
      "kvm"
      "vboxusers"
      "video"
      "wheel"

      # TODO: drop this - i don't think "tty" is needed anymore with the new `programs.xorg` module
      config.programs.shadow.settings.TTYGROUP
    ];

    packages = [
      pkgs.libreoffice
      pkgs.nautilus
      pkgs.noctalia-shell
      pkgs.rclone
      pkgs.starship
      pkgs.syncthing
      pkgs.wtype
    ];
  };

  # TODO: update userborn, new version supports this!
  environment.etc.subuid.mode = "0444";
  environment.etc.subgid.mode = "0444";
  environment.etc.subuid.text = "aaron:100000:65536";
  environment.etc.subgid.text = "aaron:100000:65536";

  users.users.test = {
    isNormalUser = true;
    shell = pkgs.fish;
    passwordFile = config.sops.secrets."aaron/password".path;

    extraGroups = [
      config.hardware.i2c.group
      config.services.seatd.group
      "audio"
      "input"
      "video"
      "wheel"

      "tty"
    ];
  };

  environment.systemPackages = [
    pkgs.gnome-themes-extra
    pkgs.kdePackages.breeze-icons
    pkgs.xfconf
    pkgs.thunar

    pkgs.ddcutil
    pkgs.dex
    pkgs.ghostty
    pkgs.kanshi
    pkgs.musikcube
    pkgs.swayidle

    pkgs.mailutils
    pkgs.man
    # (most of) these tools can/should be moved into a local profile - but kept in sync with <nixpkgs> ideally
    pkgs.direnv
    pkgs.dnsutils
    pkgs.git
    pkgs.htop
    pkgs.lnav
    pkgs.jq
    pkgs.nix-prefetch-git
    pkgs.ncdu
    pkgs.nix-diff
    pkgs.nix-output-monitor
    pkgs.nix-top
    pkgs.nix-tree
    pkgs.sops
    pkgs.ssh-to-age
    pkgs.tree
    pkgs.wget

    (pkgs.chromium.override {
      commandLineArgs = [
        # "--enable-features=AcceleratedVideoEncoder"
        "--enable-features=AcceleratedVideoEncoder,VaapiVideoDecodeLinuxGL"
        "--ignore-gpu-blocklist"
        "--enable-zero-copy"
      ];
    })
    pkgs.firefox
    pkgs.qbittorrent
    pkgs.steam
    pkgs.steam.run
    pkgs.xarchiver

    (pkgs.vscode-with-extensions.override {
      vscodeExtensions = with pkgs.vscode-extensions; [
        bbenoist.nix
        jnoortheen.nix-ide
        mkhl.direnv
        ms-python.python
        ms-vscode-remote.remote-ssh
        rust-lang.rust-analyzer
      ];
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
    pkgs.wl-clipboard
    pkgs.xdg-utils

    pkgs.iproute2
    pkgs.iputils
    pkgs.nettools

    pkgs.bustle
    pkgs.d-spy
    pkgs.dconf-editor

    pkgs.catppuccin-cursors.mochaLight

    pkgs.dconf

    pkgs.util-linux
    pkgs.e2fsprogs
    pkgs.kbd

    pkgs.imv # TODO: set as default image viewer

    # TODO: add `programs.ssh.*` options
    pkgs.openssh
  ];

  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  # https://wiki.nixos.org/wiki/Accelerated_Video_Playback#Intel
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];
  hardware.graphics.extraPackages32 = [ pkgs.pkgsi686Linux.intel-media-driver ];
}
