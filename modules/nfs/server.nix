{ config, lib, pkgs, ... }:
# NFS failover setup based on znapzend.
#
# This setup works as follow:
# - The nfs server uses zsnapzend to sync its zfs pools to the nfs backup every 10 minutes
# - Both nfs server and nfs backup have a dedicated ip address: 2a09:80c0:102::f000:0/64 for the server
# - If the nfs server becomes unavailable the backup server can become the nfs
#   server by importing `nfs/server.nix` instead of `nfs/server-backup.nix`
#
# To migrate nfs service from one machine to another while both machines are still online, first remove
# their ipv6 addresses to avoid ipv6 duplicate address detection to fail:
#
# on the server
# ip addr del 2a09:80c0:102::f000:0/64 dev bond1
#
# on the backup machine
# ip addr del 2a09:80c0:102::f000:1/64 dev bond1
#
# Than swap the imports for `nfs/server.nix` and `nfs/server-backup.nix` in both nixos configurations.
{
  imports = [ ./. ];

  sops.secrets.znapzend = {};
  programs.ssh.extraConfig = ''
    Host nfs-backup
      User znapzend
      IdentityFile ${config.sops.secrets.znapzend.path}
  '';

  services.nfs.server.enable = true;
  # fsid is necessary so that we can failover to the backup nfs, without getting
  # stale mounts on our clients.
  services.nfs.server.exports = ''
    /export/home 2a09:80c0:102::/64(rw,nohide,insecure,no_subtree_check,no_root_squash,fsid=25)
    /export/share 2a09:80c0:102::/64(rw,nohide,insecure,no_subtree_check,no_root_squash,fsid=26)
  '';

  systemd.tmpfiles.rules =
    let
      loginUsers = lib.filterAttrs (n: v: v.isNormalUser) config.users.users;
    in
      (lib.mapAttrsToList (n: v: "d /export/share/${n} 0755 ${n} users -") loginUsers)
      ++ (builtins.map (n: "R /export/share/${n} - - - - -") config.users.deletedUsers);

  boot.zfs.extraPools = [ "zpool1" "zpool2" ];

  fileSystems."/export/home" = {
    device = "zpool1/home";
    fsType = "zfs";
    options = [ "nofail" ];
  };

  fileSystems."/export/share" = {
    device = "zpool2/share";
    fsType = "zfs";
    options = [ "nofail" ];
  };

  systemd.services.znapzend-setup = {
    wantedBy = ["multi-user.target"];
    before = ["znapzend"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = [
        # delete nfs backup server ip if present.
        "-${pkgs.iproute2}/bin/ip addr del 2a09:80c0:102::f000:1/64 dev bond1"
        # add nfs server ip
        "-${pkgs.iproute2}/bin/ip addr add 2a09:80c0:102::f000:0/64 dev bond1"
      ];
    };
  };

  services.znapzend.enable = true;
  services.znapzend.zetup = let
    postsend = task: toString (pkgs.writeScript "postsend" ''
      cat > /var/log/telegraf/${task} <<EOF
      task,frequency=tenminutes last_run=$(date +%s)i,state="ok"
      EOF
    '');
  in {
    "zpool1" = {
      plan = "1h=>10min";
      recursive = true;
      destinations.remote = {
        host = "znapzend@nfs-backup";
        dataset = "zpool1";
        postsend = postsend "znapzend-home";
      };
    };
    "zpool2" = {
      plan = "1h=>10min";
      recursive = true;
      destinations = {
        remote = {
          host = "znapzend@nfs-backup";
          dataset = "zpool2";
          postsend = postsend "znapzend-share";
        };
      };
    };
  };
}
