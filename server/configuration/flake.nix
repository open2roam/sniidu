{
  description = "NixOS configuration for open2log server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      disko,
      sops-nix,
      ...
    }@inputs:
    {
      nixosConfigurations.memento-mori = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          ./hardware-configuration.nix
          ./disk-config.nix
          ../modules/base.nix
          ../modules/firewall.nix
          ../modules/phoenix.nix
          ../modules/gluetun.nix
          ../modules/litestream.nix
          ../modules/crawler.nix
        ];
      };
    };
}
