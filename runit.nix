{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.runit;

  serviceOpts =
    { name, ... }:
    {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Whether to generate and supervise this runit service. When
            false, nothing is created under `/etc/service` for this
            service.
          '';
        };

        run = lib.mkOption {
          type = lib.types.str;
          description = ''
            Body of the service `run` script. A shebang line is prepended
            automatically. The script must `exec` the service in the
            foreground so that runit can supervise it.
          '';
        };

        finish = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = ''
            Body of the optional `finish` script, executed by runit after
            the service exits.
          '';
        };

        log = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = ''
            When non-null, the body of the `log/run` script. Enables a
            logger co-process supervised alongside the service.
          '';
        };

        down = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            If true, an empty `down` file is created in the service
            directory so runit does not start the service automatically.
          '';
        };
      };
    };

  mkSvDir =
    name: svc:
    let
      runScript = pkgs.writeShellScript "runit-${name}-run" svc.run;
      finishScript =
        if svc.finish != null then pkgs.writeShellScript "runit-${name}-finish" svc.finish else null;
      logScript =
        if svc.log != null then pkgs.writeShellScript "runit-${name}-log-run" svc.log else null;
    in
    pkgs.runCommandLocal "runit-sv-${name}" { } ''
      mkdir -p $out
      ln -s ${runScript} $out/run
      ln -s /run/runit/${name} $out/supervise
      ${lib.optionalString (finishScript != null) "ln -s ${finishScript} $out/finish"}
      ${lib.optionalString svc.down "touch $out/down"}
      ${lib.optionalString (logScript != null) ''
        mkdir -p $out/log
        ln -s ${logScript} $out/log/run
        ln -s /run/runit/${name}/log $out/log/supervise
      ''}
    '';
in
{
  options.runit = {
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.runit;
      defaultText = lib.literalExpression "pkgs.runit";
      description = ''
        The package providing `runit`, `runsv`, `runsvdir`, `sv`, and
        `chpst`.
      '';
    };

    services = lib.mkOption {
      type = with lib.types; attrsOf (submodule serviceOpts);
      default = { };
      example = lib.literalExpression ''
        {
          chronyd.run = "exec ''${pkgs.chrony}/bin/chronyd -d";
        }
      '';
      description = ''
        Attribute set of runit services. For each enabled service `name`,
        a service directory is symlinked at `/etc/service/<name>`.
        `runsvdir` is expected to supervise `/etc/service`.
      '';
    };
  };

  config = {
    environment.systemPackages = [ cfg.package ];

    environment.etc = lib.mapAttrs' (name: svc: {
      name = "service/${name}";
      value.source = mkSvDir name svc;
    }) (lib.filterAttrs (_: svc: svc.enable) cfg.services);

    finit.services.runsvdir = {
      description = "runit service supervisor";
      command = "${config.runit.package}/bin/runsvdir -P /etc/service";
      path = [ config.runit.package ];
      runlevels = "2345";
      log = true;
    };

    finit.tmpfiles.rules =
      [
        "d /etc/service"
        "d /run/runit"
      ]
      ++ lib.concatLists (
        lib.mapAttrsToList (
          name: svc:
          [ "d /run/runit/${name}" ] ++ lib.optional (svc.log != null) "d /run/runit/${name}/log"
        ) (lib.filterAttrs (_: svc: svc.enable) cfg.services)
      );
  };
}
