{
  lib,
  options,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sops;
  secretsForUsers = lib.filterAttrs (_: v: v.neededForUsers) cfg.secrets;
  templatesForUsers = { }; # We do not currently support `neededForUsers` for templates.
  manifestFor = pkgs.callPackage ../manifest-for.nix {
    inherit cfg;
    inherit (pkgs) writeTextFile;
  };
  withEnvironment = import ../with-environment.nix {
    # See also the default NixOS module.
    cfg = lib.recursiveUpdate cfg {
      environment.HOME = "/var/empty";
    };
    inherit lib;
  };
  manifestForUsers = manifestFor "-for-users" secretsForUsers templatesForUsers {
    secretsMountPoint = "/run/secrets-for-users.d";
    symlinkPath = "/run/secrets-for-users";
  };
in
{
  system.activation.scripts = lib.mkIf (secretsForUsers != { }) {
    setupSecretsForUsers =
      lib.stringAfter (lib.optional cfg.age.generateKey "generate-age-key") ''
        [ -e /run/current-system ] || echo setting up secrets for users...
        ${withEnvironment "${cfg.package}/bin/sops-install-secrets -ignore-passwd ${manifestForUsers}"}
      ''
      // lib.optionalAttrs (config.system ? dryActivationScript) {
        supportsDryActivation = true;
      };

    users.deps = [ "setupSecretsForUsers" ];
  };

  assertions = [
    {
      assertion =
        (lib.filterAttrs (
          _: v: (v.uid != 0 && v.owner != "root") || (v.gid != 0 && v.group != "root")
        ) secretsForUsers) == { };
      message = "neededForUsers cannot be used for secrets that are not root-owned";
    }
  ];

  # system.build.sops-nix-users-manifest = manifestForUsers;
}
