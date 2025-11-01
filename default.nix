let
  inherit (pkgs) lib;

  pkgs = import <nixpkgs> {
    system = "x86_64-linux";

    config.allowUnfree = true;
    overlays = [
      (import <finix/overlays>)
      (import <finix/overlays/modular-services.nix>)

      (final: prev: {
        inherit (import <sops-nix> { pkgs = final; }) sops-install-secrets;
      })

      (final: prev: {
        hyprland = prev.hyprland.override { withSystemd = false; };
        niri = prev.niri.override { withSystemd = false; };
        # procps = prev.procps.override { withSystemd = false; };
        seatd = prev.seatd.override { systemdSupport = false; };
        swayidle = prev.swayidle.override { systemdSupport = false; };
        xdg-desktop-portal = prev.xdg-desktop-portal.override { enableSystemd = false; };
        xwayland-satellite = prev.xwayland-satellite.override { withSystemd = false; };
      })
    ];
  };

  modules = lib.attrValues {
    inherit (import <finix/modules>)
      # required for evaluation
      default
      dbus
      elogind
      mdevd
      privileges
      scheduler
      seatd
      tmpfiles
      udev

      anacron
      atd
      bash
      bluetooth
      brightnessctl
      chronyd
      ddccontrol
      dropbear
      fcron
      fish
      fprintd
      fstrim
      fwupd
      getty
      gnome-keyring
      greetd
      hyprlock
      incus
      iwd
      labwc
      mariadb
      niri
      nix-daemon
      nzbget
      openresolv
      openssh
      polkit
      power-profiles-daemon
      regreet
      rtkit
      seahorse
      sysklogd
      system76-scheduler
      tzupdate
      upower
      uptime-kuma
      virtualbox
      xwayland-satellite
      zerotierone
      zfs

      # testing
      hyprland
      sway
    ;
  };

  os = lib.evalModules {
    specialArgs = {
      modulesPath = toString <nixpkgs/nixos/modules>;
    };

    modules = [
      { nixpkgs.pkgs = pkgs; }
      ./configuration.nix
      <nixpkgs/nixos/modules/programs/xfconf.nix>
    ] ++ modules;
  };
in
  os.config.system.topLevel
