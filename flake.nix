{
  description = "";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    inherit (pkgs) lib;
  in {
    nixosModule = self.nixosModules.ovz-container;
    nixosModules = rec {
      default = ovz-container;
      ovz-container = import ./nixos.nix;
      ovz-installer = import ./installer.nix;
    };

    lib.generateOpenVzTarball = let
      f = lib.makeOverridable (import ./generate-openvz-tarball.nix) {
        inherit pkgs;
      };
    in f.override;
  };
}
