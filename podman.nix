{ pkgs, ... }:
{
  environment.etc.subuid = {
    mode = "0644";
    text = "aaron:100000:65536";
  };

  environment.etc.subgid = {
    mode = "0644";
    text = "aaron:100000:65536";
  };

  environment.systemPackages = [ pkgs.podman ];

  finit.cgroups.podman = { };
  finit.services.podman = {
    description = "podman api for aaron";
    command = "${pkgs.podman}/bin/podman system service --time=0 unix:///run/podman/podman.sock";
    user = "podman";
    group = "users";
    cgroup.name = "podman";
    cgroup.delegate = true;
    log = true;
    path = [ "/run/wrappers" ];
  };

  finit.tmpfiles.rules = [
    "d /run/podman"
    "d /var/lib/podman"
  ];

  users.users.podman = {
    group = "users";
    home = "/var/lib/podman";
  };

  users.groups.podman = { };
}
