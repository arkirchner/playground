{
  description = "Talos Linux 3-Node Cluster Prototype with OpenTofu";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            talosctl
            opentofu
          ];

          shellHook = ''
            echo "Talos cluster development environment"
            echo "  talosctl: $(talosctl version --client --short 2>/dev/null | tail -n1)"
            echo "  tofu: $(tofu version 2>/dev/null | head -n1 || echo 'available')"
          '';
        };
      });
}
