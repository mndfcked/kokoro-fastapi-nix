{
  description = "NixOS module for Kokoro-FastAPI TTS service";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }: {
    # NixOS module
    nixosModules.default = ./kokoro-fastapi.nix;
    nixosModules.kokoro-fastapi = ./kokoro-fastapi.nix;

    # Example configuration for testing
    packages.x86_64-linux.example = nixpkgs.legacyPackages.x86_64-linux.writeText "example-config.nix" ''
      # Example NixOS configuration
      { config, pkgs, ... }:
      {
        imports = [ 
          (builtins.fetchGit {
            url = "https://github.com/mndfcked/kokoro-fastapi-nix";
            # or use local path: /path/to/this/repository
          })
        ];

        services.kokoro-fastapi = {
          enable = true;
          port = 8880;
          useGpu = false;  # Set to true if you have NVIDIA GPU
          openFirewall = true;  # Allow access from local network
        };
      }
    '';

    # Development shell
    devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
      buildInputs = with nixpkgs.legacyPackages.x86_64-linux; [
        nixpkgs-fmt
        nil
        git
      ];
    };
  };
}