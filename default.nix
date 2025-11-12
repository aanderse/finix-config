let
  inherit (pkgs) lib;

  sources = import ./lon.nix;

  finix = import sources.finix;

  pkgs = import sources.nixpkgs {
    system = "x86_64-linux";

    config.allowUnfree = true;
    overlays = [
      finix.overlays.default
      finix.overlays.modular-services

      (final: prev: {
        inherit (import sources.sops-nix { pkgs = final; }) sops-install-secrets;
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
in
finix.lib.finixSystem {
  inherit lib;

  specialArgs = {
    modulesPath = toString sources.nixpkgs + "/nixos/modules";
  };

  modules = with finix.nixosModules; [
    { nixpkgs.pkgs = pkgs; }
    ./configuration.nix
    (toString sources.nixpkgs + "/nixos/modules/programs/xfconf.nix")

    # TODO: rename to resolvconf and make a required module? ... or... just have modules which need this import it? but then how to let downstream users replace it? doesn't seem great
    openresolv

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
    hyprland
    hyprlock
    incus
    iwd
    labwc
    limine
    mariadb
    niri
    nix-daemon
    nzbget
    openssh
    polkit
    power-profiles-daemon
    regreet
    rtkit
    seahorse
    sudo
    sway
    sysklogd
    system76-scheduler
    tzupdate
    upower
    uptime-kuma
    virtualbox
    xwayland-satellite
    zerotierone
    zfs
    # zzz
  ];
}
