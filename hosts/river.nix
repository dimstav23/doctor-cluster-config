{
  imports = [
    ../modules/hardware/supermicro-x12spw-tf.nix
    ../modules/nfs/client.nix
    ../modules/dpdk.nix
    ../modules/vfio/iommu-intel.nix
    ../modules/lowlatency-vm-host.nix
  ];

  # eno1 is the direct low-latency link to christina; keep networkd from
  # putting addresses on it.
  systemd.network.networks."04-lowlat-eno1" = {
    matchConfig.Name = "eno1";
    networkConfig = {
      DHCP = "no";
      LinkLocalAddressing = "no";
      IPv6AcceptRA = false;
    };
    linkConfig.RequiredForOnline = "no";
  };

  boot.hugepages1GB.number = 8;
  boot.hugepages2MB.number =
    let
      gb = 100;
    in
    gb * 1024 / 2;

  networking.hostName = "river";

  simd.arch = "icelake-server";

  system.stateVersion = "21.11";
}
