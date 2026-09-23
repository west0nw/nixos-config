# NixOS Configuration Flake
# Hosts: nullrunner (Framework 16) and scar (ASUS server)

{
  description = "NixOS configurations for nullrunner and scar";

  inputs = {
    # Package repository
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Current Codex CLI without updating the full system package set
    nixpkgs-codex.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Official ChatGPT/Codex desktop app packaged for NixOS
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs-codex";
    };

    # OpenCode 2 (CLI from upstream flake, desktop from matching official AppImage)
    nixpkgs-opencode.url = "github:anomalyco/opencode/v2.0.15";

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
      llm-agents,
      nixpkgs-opencode,
      matt-pocock-skills,
      nixos-hardware,
      home-manager,
      nixvim,
      stylix,
      spicetify-nix,
    }@inputs:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      # Repository tools are pinned with the system; no global installs are needed.
      devShells.x86_64-linux.default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          nixfmt
          shellcheck
          nodejs
          python3
          jujutsu
          ripgrep
        ];
      };
      formatter.x86_64-linux = pkgs.writeShellApplication {
        name = "format-nix-config";
        runtimeInputs = with pkgs; [
          nixfmt
          ripgrep
          findutils
        ];
        text = ''
          if (( $# > 0 )) && [[ "$1" != --* ]]; then
            exec nixfmt "$@"
          fi
          rg --files --hidden -g '*.nix' -g '!hardware-configuration.nix' \
            -g '!.git/**' -g '!.jj/**' -0 | xargs -0 -r nixfmt "$@"
        '';
      };
      checks.x86_64-linux.desktop-scripts =
        pkgs.runCommand "check-desktop-scripts"
          {
            nativeBuildInputs = with pkgs; [
              bash
              shellcheck
              python3
              jq
              coreutils
              nodejs
            ];
          }
          ''
            shellcheck ${./home/westonw/scripts}/*.sh
            node --input-type=module --check < ${./home/westonw/opencode/plugins/goal.js}
            node ${./tests/test_goal_plugin.mjs} ${./home/westonw/opencode/plugins/goal.js}
            python3 ${./tests/test_desktop_scripts.py} ${./home/westonw/scripts}
            touch "$out"
          '';

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
