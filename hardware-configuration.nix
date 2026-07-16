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
    device = "/dev/disk/by-uuid/35E7-B286";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
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
