{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "UUID=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX";
    fsType = "btrfs";
    options = [ "subvol=@" "compress=zstd" ];
  };

  fileSystems."/mnt/persist" = {
    device = "UUID=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX";
    fsType = "btrfs";
    options = [ "subvol=@persist" "compress=zstd" ];
  };

  fileSystems."/boot" = {
    device = "UUID=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX";
    fsType = "vfat";
  };

  swapDevices = [
    { device = "/dev/disk/by-label/swap"; }
  ];

  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = false;
  networking.interfaces.eth1.useDHCP = false;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}

