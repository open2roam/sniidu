{
  lib,
  config,
  ...
}:
{
  options.myHost.disko.disks = lib.mkOption {
    type = lib.types.listOf lib.types.path;
    default = [
      "/dev/nvme0n1"
      "/dev/nvme1n1"
      "/dev/nvme2n1"
    ];
    description = lib.mdDoc "Disks formatted by disko (3x3.84TB NVMe)";
  };

  options.myHost.disko.boot_fallback_disk_count = lib.mkOption {
    type = lib.types.int;
    default = 2;
    description = lib.mdDoc "Number of fallback boot disks";
  };

  options.myHost.disko.raidz_level = lib.mkOption {
    type = lib.types.str;
    default = "raidz1";
    description = lib.mdDoc "RAIDZ level (raidz1 = can lose 1 disk)";
  };

  options.myHost.disko.swap_size_per_disk = lib.mkOption {
    type = lib.types.str;
    default = "32G";
    description = lib.mdDoc "Swap partition size per disk";
  };

  config = {
    boot.loader = {
      efi.canTouchEfiVariables = false;
      grub = {
        device = "nodev";
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        mirroredBoots = [
          {
            path = "/boot-fallback-1";
            devices = [ "nodev" ];
          }
          {
            path = "/boot-fallback-2";
            devices = [ "nodev" ];
          }
        ];
      };
    };

    # Fix zpool import timeout issues
    boot.initrd.systemd.services.zfs-import-zroot.serviceConfig = {
      ExecStartPre = "${config.boot.zfs.package}/bin/zpool import -N -f zroot";
      Restart = "on-failure";
    };

    # Trim unused blocks from ZFS CoW operations
    services.fstrim.enable = true;
    services.zfs.trim.enable = true;

    # Weekly scrub to detect and fix corruption
    services.zfs.autoScrub.enable = true;
    services.zfs.autoScrub.interval = "weekly";

    disko.devices = {
      disk = lib.genAttrs config.myHost.disko.disks (device: {
        name = lib.replaceStrings [ "/" ] [ "_" ] device;
        device = device;
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02"; # GRUB MBR
            };
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint =
                  lib.mkIf
                    (builtins.elem device (
                      lib.lists.take (1 + config.myHost.disko.boot_fallback_disk_count) config.myHost.disko.disks
                    ))
                    "/boot${
                      if device == (builtins.elemAt config.myHost.disko.disks 0) then
                        ""
                      else
                        "-fallback-" + toString (lib.lists.findFirstIndex (x: x == device) null config.myHost.disko.disks)
                    }";
                mountOptions = [
                  "nofail"
                  "umask=0077"
                ];
              };
            };
            swap = {
              size = config.myHost.disko.swap_size_per_disk;
              content = {
                type = "swap";
                randomEncryption = true;
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      });

      zpool = {
        zroot = {
          type = "zpool";
          mode = config.myHost.disko.raidz_level;
          rootFsOptions = {
            canmount = "off";
          };
          # 4KB sectors for NVMe (ashift=12)
          options.ashift = "12";

          datasets = {
            root = {
              type = "zfs_fs";
              mountpoint = "/";
              options.mountpoint = "legacy";
              options = {
                compression = "zstd";
                "com.sun:auto-snapshot" = "false";
              };
            };
            # DuckDB/DuckLake data
            data = {
              type = "zfs_fs";
              mountpoint = "/var/lib/ducklake";
              options.mountpoint = "legacy";
              options = {
                acltype = "posixacl";
                atime = "off";
                compression = "zstd-3";
                xattr = "sa";
                redundant_metadata = "most";
                "com.sun:auto-snapshot" = "false";
              };
            };
            # Phoenix app data
            phoenix = {
              type = "zfs_fs";
              mountpoint = "/var/lib/phoenix";
              options.mountpoint = "legacy";
              options = {
                compression = "zstd";
                "com.sun:auto-snapshot" = "false";
              };
            };
          };
        };
      };
    };
  };
}
