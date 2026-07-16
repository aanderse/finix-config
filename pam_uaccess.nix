{
  acl,
  fetchFromSourcehut,
  lib,
  meson,
  ninja,
  pam,
  pkg-config,
  stdenv,
  udev,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "pam_uaccess";
  version = "0.6.1";

  src = fetchFromSourcehut {
    owner = "~kennylevinsen";
    repo = "pam_uaccess";
    rev = "54fbf043c63cc500b4850b0b4a12ea14078f2b53";
    hash = "sha256-7Npxuj9C/OiYM3Gvm4AbDI9lLWO+lYWqt4ptSzhDBiA=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ];
  buildInputs = [
    acl
    pam
    udev
  ];

  meta = {
    homepage = "https://git.sr.ht/~kennylevinsen/pam_uaccess";
    description = "Grants access to devices tagged \"uaccess\" in udev for the duration of the users session";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    maintainers = with lib.maintainers; [ aanderse ];
  };
})
