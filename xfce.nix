{
  modules,
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.xfce4;

  sessionFile = pkgs.writeTextDir "share/wayland-sessions/xfce-wayland.desktop" ''
    [Desktop Entry]
    Version=1.0
    Name=Xfce Session (Wayland)
    Comment=Use this session to run Xfce as your desktop environment
    Exec=startxfce4 --wayland ${lib.getExe cfg.compositor.package} ${toString cfg.compositor.extraArgs}
    Icon=
    Type=Application
    DesktopNames=XFCE
    Keywords=xfce;wayland;desktop;environment;session;
  '';
in
{
  imports = with modules; [
    labwc
    xfconf
  ];

  options.programs.xfce4 = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    compositor = {
      package = lib.mkOption {
        type = lib.types.package;
        default = config.programs.labwc.package;
        defaultText = lib.literalExpression "config.programs.labwc.package";
        description = ''
          The package to use for `labwc`.
        '';
      };

      extraArgs = lib.mkOption {
        type = with lib.types; listOf str;
        default = [ "-s" ];
        description = ''
          Additional arguments to pass to `cage`. See [upstream documentation](https://github.com/cage-kiosk/cage/blob/master/cage.1.scd#options)
          for additional details.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.xfconf.enable = true;

    services.dbus.packages = [ pkgs.xfce4-notifyd ];

    environment.systemPackages = [
      # primary package - takes care of dbus-run-session for us :)
      pkgs.xfce4-session

      # window manager
      pkgs.xfwm4
      pkgs.xfwm4-themes

      # desktop & panel
      pkgs.xfce4-panel
      pkgs.xfdesktop

      # override wayland session with one that includes absolute paths + dbus-run-session invocation
      (lib.hiPrio sessionFile)
    ];
  };
}
