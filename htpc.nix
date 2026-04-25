{
  config,
  pkgs,
  lib,
  ...
}:
let
  kodi' =
    (pkgs.kodi-wayland.override (
      lib.optionalAttrs config.services.mdevd.enable {
        udev = pkgs.libudev-zero;

        libcec = pkgs.libcec.override {
          udev = pkgs.libudev-zero;
        };
      }
    )).overrideAttrs
      (o: {
        patches =
          o.patches or [ ]
          ++ lib.optionals config.services.mdevd.enable [
            (pkgs.fetchpatch {
              url = "https://github.com/xbmc/xbmc/commit/d7bc7c022f2eac6adcdd822144e75030aa677191.patch";
              hash = "sha256-judnNhb4IT7v4ZfZNHKrLh3GNgYplpga0bQJR9lqxGQ=";
            })
          ];
      });

  advancedsettings = pkgs.writeText "advancedsettings.xml" ''
    <advancedsettings version="1.0">
      <powermanagement>
        <powerdown>sudo poweroff</powerdown>
        <reboot>sudo reboot</reboot>
        <suspend>sudo zzz</suspend>
        <hibernate>sudo ZZZ</hibernate>
      </powermanagement>
    </advancedsettings>
  '';

  libinput = pkgs.libinput.override (
    lib.optionalAttrs config.services.mdevd.enable {
      udev = pkgs.libudev-zero;
      wacomSupport = false;
    }
  );

  labwc = pkgs.labwc.override {
    inherit libinput;

    wlroots_0_19 = pkgs.wlroots_0_19.override { inherit libinput; };
  };
in
{
  environment.systemPackages = [
    (kodi'.withPackages (p: [
      p.a4ksubtitles
      p.jellycon
      p.jellyfin
      p.steam-library
    ]))

    (pkgs.writeTextDir "share/wayland-sessions/htpc.desktop" ''
      [Desktop Entry]
      Comment=htpc test
      DesktopNames=kodi
      Exec=${pkgs.dbus}/bin/dbus-run-session -- ${lib.getExe labwc} --session ${pkgs.writeShellScript "launch-kodi.sh" "exec ${kodi'}/bin/kodi --settings=${advancedsettings}"}
      Icon=kodi
      Name=kodi
      Type=Application
    '')
  ];

  users.users.htpc = {
    isNormalUser = true;
    passwordFile = config.sops.secrets."aaron/password".path;

    extraGroups = [
      config.services.seatd.group
      "audio"
      "input"
      "video"
    ];
  };
}
