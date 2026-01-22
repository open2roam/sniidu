{
  description = "open2log - Grocery price tracking system";

  inputs = {
    # Use srvos for server defaults and Hetzner hardware support
    srvos.url = "github:nix-community/srvos";
    nixpkgs.follows = "srvos/nixpkgs";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Fetch SSH keys from GitHub
    onnimonni-ssh-keys = {
      url = "https://github.com/onnimonni.keys";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      srvos,
      disko,
      sops-nix,
      ...
    }@inputs:
    {
      nixosConfigurations.memento-mori = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
          # nixos-anywhere terraform module will inject values here
          terraformArgs = { };
        };
        modules = [
          # Server defaults from srvos
          srvos.nixosModules.server
          srvos.nixosModules.hardware-hetzner-online-amd
          # Disko for disk management
          disko.nixosModules.disko
          # SOPS for secrets
          sops-nix.nixosModules.sops
          # Hardware config
          ./server/configuration/hardware-configuration.nix
          # ZFS disk layout for 3x3.84TB NVMe
          ./server/modules/disko-zfs.nix
          # Server modules
          ./server/modules/base.nix
          ./server/modules/firewall.nix
          ./server/modules/phoenix.nix
          ./server/modules/gluetun.nix
          ./server/modules/litestream.nix
          ./server/modules/crawler.nix
          # Server-specific config
          ./server/configuration/memento-mori.nix
        ];
      };
    };
}
