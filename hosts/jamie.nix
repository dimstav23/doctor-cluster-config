{ pkgs, ... }:
{
  imports = [
    ../modules/hardware/poweredge7625.nix
    ../modules/nfs/client.nix
    # jamie alternates between two lanes (patrick, Wallet-GPU):
    #  - CoCo/veritas: SVSM host kernel 6.11-vc, no host nvidia driver
    #  - native GPU:   amd_sev_snp.nix + ../modules/nvidia (6.11-vc
    #                  breaks cuInit)
    # Flip these three lines, do not deploy from an old checkout.
    #../modules/amd_sev_snp.nix
    ../modules/amd_sev_svsm.nix
    #../modules/nvidia
    ../modules/vfio/iommu-amd.nix

    ../modules/kata-container
    ../modules/tribuchet
  ];

  # H100 runs in Confidential Compute mode for SEV-SNP passthrough; the host
  # driver cannot initialize it, so CDI generation fails and breaks activation.
  hardware.nvidia-container-toolkit.enable = false;

  simd.arch = "znver4";

  disko.rootDisk = "/dev/disk/by-id/nvme-SAMSUNG_MZQL23T8HCLS-00A07_S64HNJ0X815786";

  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
  };

  networking.hostName = "jamie";

  system.stateVersion = "23.05";

  # No kernel reboots during the veritas experiments (Teofil, 6f783a9e).
  dse.autoReboot.pauseUntil = "2026-09-12";
}
