{
  description = "AIS Dispatcher for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "armv7l-linux" "armv6l-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          aisdispatcher = pkgs.callPackage ./package.nix { };
          default = self.packages.${system}.aisdispatcher;
        }
      );

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              nixos-rebuild
              nix-output-monitor
            ];
          };
        }
      );

      nixosModules = {
        aisdispatcher = import ./module.nix;
        default = self.nixosModules.aisdispatcher;
      };

      # Overlay for adding the package to nixpkgs
      overlays.default = final: prev: {
        aisdispatcher = final.callPackage ./package.nix { };
      };
    };
}
