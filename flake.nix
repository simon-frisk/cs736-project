{
  description = "Multitenant cache project";

  # Flake inputs
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
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
        default = pkgs.mkShell {
          # The Nix packages provided in the environment
          packages = with pkgs; [clang_18 cmake];
        };
      });
      packages = forAllSystems ({ pkgs }: {
        default =
          let
            binName = "mtcache";
            cppDependencies = with pkgs; [clang_18 cmake];
          in
          pkgs.stdenv.mkDerivation {
            name = "mtcache";
            src = self;
            nativeBuildInputs = cppDependencies;
            installPhase = ''
              mkdir -p $out/bin
              cp bin/${binName} $out/bin/
            '';
          };
      });
    };
}