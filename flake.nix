# NixOS Configuration Flake
# Hosts: nullrunner (Framework 16) and scar (ASUS server)

{
  description = "NixOS configurations for nullrunner and scar";

  inputs = {
    # Package repository
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Current Codex CLI without updating the full system package set
    nixpkgs-codex.url = "github:NixOS/nixpkgs/nixos-unstable";

    # OpenCode (latest from upstream flake)
    nixpkgs-opencode.url = "github:anomalyco/opencode/v1.18.3";

    # Matt Pocock's engineering skills for OpenCode
    matt-pocock-skills = {
      url = "github:mattpocock/skills";
      flake = false;
    };

    # Hardware-specific modules (Framework laptop)
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    # Home manager for user environment
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative neovim configuration
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Consistent theming engine
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Spicetify for Spotify theming
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-codex,
      nixpkgs-opencode,
      matt-pocock-skills,
      nixos-hardware,
      home-manager,
      nixvim,
      stylix,
      spicetify-nix,
    }@inputs:
    {
      nixosConfigurations.nullrunner = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          {
            nixpkgs.hostPlatform = "x86_64-linux";
          }

          # Hardware configuration
          nixos-hardware.nixosModules.framework-16-amd-ai-300-series

          # System configuration
          ./hosts/nullrunner

          # Stylix theming
          stylix.nixosModules.stylix

          # Home manager as NixOS module
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users.westonw = import ./home/westonw;
            home-manager.extraSpecialArgs = {
              inherit inputs;
              inherit (inputs) spicetify-nix;
            };
          }
        ];
      };

      nixosConfigurations.scar = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          {
            nixpkgs.hostPlatform = "x86_64-linux";
          }

          # System configuration
          ./hosts/scar

          # Home manager as NixOS module
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users.westonw = import ./home/westonw/server.nix;
            home-manager.extraSpecialArgs = {
              inherit inputs;
              inherit (inputs) spicetify-nix;
            };
          }
        ];
      };
    };
}
