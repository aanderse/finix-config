final: prev:
let
  xserver = {
    version = "25.2.0";
    hash = "sha256-zyT7MyTMlVCodI6+GKVs1Z+pkWy6Rawpn0L6uJNgWfA=";
  };

  libinput = {
    version = "25.0.1";
    hash = "sha256-dCpnup8MCmwpZp9jPGCZYnjBwu13r2o1gWm8mAw9U+A=";
  };
in
{
  xorg-server = prev.xorg-server.overrideAttrs (old: {
    inherit (xserver) version;

    pname = "xlibre-xserver";

    src = final.fetchFromGitHub {
      owner = "X11Libre";
      repo = "xserver";
      tag = "xlibre-xserver-${xserver.version}";
      inherit (xserver) hash;
    };

    buildInputs = old.buildInputs ++ [ final.seatd ];
    mesonFlags = old.mesonFlags ++ [ "-Dseatd_libseat=true" ];
  });

  xf86-input-libinput =
    (prev.xf86-input-libinput.override { xorg-server = final.xorg-server; }).overrideAttrs
      (old: {
        inherit (libinput) version;

        pname = "xlibre-xf86-input-libinput";

        src = final.fetchFromGitHub {
          inherit (libinput) hash;

          owner = "X11Libre";
          repo = "xf86-input-libinput";
          tag = "xlibre-xf86-input-libinput-${libinput.version}";
        };

        configureFlags = old.configureFlags ++ [
          "--with-xorg-module-dir=${placeholder "out"}/lib/xorg/modules"
        ];
      });
}
