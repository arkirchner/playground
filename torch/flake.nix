{
  description = "Ruby 4 + libtorch dev shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      libtorch = pkgs.fetchzip {
        url = "https://download.pytorch.org/libtorch/cpu/libtorch-shared-with-deps-2.10.0%2Bcpu.zip";
        sha256 = "05wjx5gdr0y3vn6ajbgv3zx9p5qw83f6rnndnssml3snmkrlpb41";
      };
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.ruby_4_0
        ];

        BUNDLE_PATH = ".bundle";

        shellHook = ''
          bundle config set build.torch-rb --with-torch-dir=${libtorch}
        '';
      };
    };
}
