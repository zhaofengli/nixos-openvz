{
  pkgs ? import <nixpkgs> { system = "x86_64-linux"; overlays = []; },
  configuration ? {},
}:
let
  nixos = pkgs.nixos {
    imports = [
      configuration
      ./nixos.nix
      ./installer.nix
    ];
  };
in nixos.config.system.build.tarball
