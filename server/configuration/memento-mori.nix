# Server-specific configuration for memento-mori (Hetzner auction server)
{
  inputs,
  lib,
  pkgs,
  config,
  terraformArgs,
  ...
}:
let
  inherit (inputs) onnimonni-ssh-keys;
in
{
  networking.hostName = "memento-mori";

  # Each disk is 3.84TB, contains small boot partitions and rest is for zfs pool
  # IMPORTANT: If you get more disks, don't change the order of the first disks
  # TODO: Update these with actual disk IDs after first deployment
  myHost.disko.disks = [
    # Primary boot disk, mounted as /boot
    "/dev/nvme0n1"
    # Fallback boot disk 1, mounted as /boot-fallback-1
    "/dev/nvme1n1"
    # Fallback boot disk 2, mounted as /boot-fallback-2
    "/dev/nvme2n1"
  ];

  # Enable nix-channel for building directly on server (useful with Apple Silicon)
  nix.channel.enable = lib.mkForce true;

  users.users = {
    onnimonni = {
      isNormalUser = true;
      shell = pkgs.fish;
      extraGroups = [
        "users"
        "wheel"
      ];
      openssh.authorizedKeys.keyFiles = [ onnimonni-ssh-keys.outPath ];
    };
  };

  # nixos-anywhere needs root keys
  users.users.root.openssh.authorizedKeys.keyFiles = [ onnimonni-ssh-keys.outPath ];

  # Skip fsck at startup (always fails, blocks boot until you press *)
  boot.initrd.checkJournalingFS = false;

  # Hetzner uses BIOS legacy boot, not systemd-boot
  boot.loader.systemd-boot.enable = false;

  boot.initrd.kernelModules = [ "kvm-amd" ];

  # Performance: disable power saving
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

  # IPv6 configuration (configured via SOPS)
  networking.enableIPv6 = true;
  systemd.network.networks."10-uplink".networkConfig.Address = lib.mkDefault "";

  # Prefer IPv4 over IPv6 to avoid timeout issues
  environment.etc."gai.conf".text = ''
    # Prefer IPv4 over IPv6
    precedence ::ffff:0:0/96  100
  '';

  # Restart networkd when config changes to apply IPv6
  systemd.services.systemd-networkd.restartTriggers = [
    config.environment.etc."systemd/network/10-uplink.network".source
  ];

  # Useful tools
  environment.systemPackages = [ pkgs.rclone ];

  system.stateVersion = "25.05";
}
