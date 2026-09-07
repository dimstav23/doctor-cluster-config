# Isolate cores 8-11 for latency-sensitive VM/DPDK work; housekeeping,
# IRQs, kthreads and all systemd-spawned processes stay on 0-7.
{
  powerManagement.enable = true;
  powerManagement.cpuFreqGovernor = "performance";

  boot.kernelParams = [
    "nosmt"
    "isolcpus=8-11"
    "nohz_full=8-11"
    "rcu_nocbs=8-11"
    "rcu_nocb_poll"
    "irqaffinity=0-7"
    "kthread_cpus=0-7"
    "intel_idle.max_cstate=0"
    "idle=poll"
    "nowatchdog"
    "tsc=reliable"
    "skew_tick=1"
    "audit=0"
  ];

  systemd.settings.Manager.CPUAffinity = "0-7";
  systemd.user.extraConfig = ''
    [Manager]
    CPUAffinity=0-7
  '';
}
