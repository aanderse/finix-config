# Overlay to fix packages for musl compatibility
# Import this in your flake.nix overlays for the musl specialisation
final: prev: {
  # libfaketime: timestamp parsing tests fail on musl
  # Known issue: https://bugs.gentoo.org/876067
  # Tests use glibc-specific time handling
  libfaketime = prev.libfaketime.overrideAttrs (old: {
    doCheck = false;
  });

  # onetbb (Intel Threading Building Blocks): exception handling tests fail
  # The test_eh_algorithms test gets unexpected exceptions on musl
  # Likely due to musl's different exception handling implementation
  onetbb = prev.onetbb.overrideAttrs (old: {
    doCheck = false;
  });

  # Add more musl fixes below as you discover them:

  # Example: package with glibc-specific features
  # somePackage = prev.somePackage.overrideAttrs (old: {
  #   doCheck = false;
  #   # or
  #   configureFlags = (old.configureFlags or []) ++ [ "--disable-feature" ];
  # });

  # Example: package that needs musl-specific patches
  # anotherPackage = prev.anotherPackage.overrideAttrs (old: {
  #   patches = (old.patches or []) ++ [
  #     (final.fetchpatch {
  #       url = "https://example.com/musl-fix.patch";
  #       hash = "sha256-...";
  #     })
  #   ];
  # });

  # Example: package that should use build platform version
  # (for build-time only dependencies that don't need to be musl)
  # buildTool = prev.buildPackages.buildTool;
}
