{
  modules,
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.openbox;

  sessionFile = pkgs.writeTextDir "share/xsessions/openbox.desktop" ''
    [Desktop Entry]
    Name=Openbox
    Comment=Log in using the Openbox window manager (without a session manager)
    Exec=${pkgs.dbus}/bin/dbus-run-session ${pkgs.openbox}/bin/openbox-session
    TryExec=${pkgs.openbox}/bin/openbox-session
    Icon=openbox
    Type=Application
  '';
in
{
  imports = [ modules.xorg ];

  options.programs.openbox = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [openbox](${pkgs.openbox.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.openbox;
      defaultText = lib.literalExpression "pkgs.openbox";
      description = "The package to use for `openbox`.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.xorg.enable = true;

    environment.systemPackages = [
      cfg.package

      # override wayland session with one that includes absolute paths + dbus-run-session invocation
      (lib.hiPrio sessionFile)
    ];
  };
}
