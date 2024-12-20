{
  description = "Multitenant cache project";

  # Flake inputs
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  # Flake outputs
  outputs = { self, nixpkgs }:
    let
      # Systems supported
      allSystems = [
        "x86_64-linux" # 64-bit Intel/AMD Linux
        "aarch64-linux" # 64-bit ARM Linux
        "x86_64-darwin" # 64-bit Intel macOS
        "aarch64-darwin" # 64-bit ARM macOS
      ];

      # Helper to provide system-specific attributes
      forAllSystems = f: nixpkgs.lib.genAttrs allSystems (system: f {
        pkgs = import nixpkgs { inherit system; };
      });
    in
    {
      # Development environment output
      devShells = forAllSystems ({ pkgs }: {
        default = (pkgs.mkShell.override { stdenv = pkgs.llvmPackages_19.stdenv; }) {
          # The Nix packages provided in the environment
          packages = with pkgs; [clang_19 cmake lldb awscli just];
        };
      });
      packages = forAllSystems ({ pkgs }: {
        default =
          let
            binName = "mtcache";
          in
          pkgs.llvmPackages_19.stdenv.mkDerivation {
            name = binName;
            src = self;
            nativeBuildInputs = with pkgs; [clang_19 cmake];
            installPhase = ''
              mkdir -p $out/bin
              cp bin/${binName} $out/bin/
            '';
          };
      });
    };
}