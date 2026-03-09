{
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [
    # FIXME: causing virtualbox not to work
    # "kvm-intel"

    # bluetooth keyboard didn't work without this
    # https://github.com/bluez/bluez/issues/531#issuecomment-1913058753
    "uhid"
  ];

  fileSystems."/" = {
    fsType = "zfs";
    device = "tank/finix";
  };

  fileSystems."/boot" = {
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
    # TODO: currently a race condition with finit/bootmisc.so and mdevd-coldplug makes using /dev/disk/by-uuid a bad idea... the path may not exist on time! bootmisc runs quite early
    device = "/dev/nvme0n1p1"; # "/dev/disk/by-uuid/35E7-B286";
  };

  fileSystems."/nix" = {
    fsType = "zfs";
    device = "tank/nix";
  };

  fileSystems."/home" = {
    fsType = "zfs";
    device = "tank/home";
  };

  fileSystems."/tmp" = {
    fsType = "tmpfs";
    options = [
      "rw"
      "nosuid"
      "nodev"
      "mode=1777"
      "X-mount.mkdir"
    ];
  };
}
