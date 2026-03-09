{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    finix.url = "github:finix-community/finix?ref=finit-4.16"; # "/home/aaron/code/finix/main";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    noctalia-shell.url = "github:noctalia-dev/noctalia-shell";
    noctalia-shell.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      finix,
      sops-nix,
      noctalia-shell,
    }:
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";

        config.allowUnfree = true;
        overlays = [
          self.overlays.custom
          sops-nix.overlays.default
          noctalia-shell.overlays.default
        ];
      };
    in
    {
      overlays.custom = final: prev: {
        # seatd = prev.seatd.override { systemdSupport = false; };
        swayidle = prev.swayidle.override { systemdSupport = false; };
        xdg-desktop-portal = prev.xdg-desktop-portal.override { enableSystemd = false; };
        xwayland-satellite = prev.xwayland-satellite.override { withSystemd = false; };
      };

      # finix
      nixosConfigurations.framework = finix.lib.finixSystem {
        inherit (pkgs) lib;

        specialArgs = {
          modulesPath = toString nixpkgs + "/nixos/modules";
        };

        modules = with finix.nixosModules; [
          {
            nixpkgs.pkgs = nixpkgs.lib.mkDefault pkgs;
          }
          ./configuration.nix

          (toString nixpkgs + "/nixos/modules/programs/noisetorch.nix")

          anacron
          atd
          bash
          bluetooth
          brightnessctl
          chronyd
          ddccontrol
          dma
          dropbear
          earlyoom
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
          illum
          incus
          iwd
          labwc
          limine
          mariadb
          nftables
          niri
          nix-daemon
          nzbget
          openssh
          pmount
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
          zzz
        ];
      };
    };
}
