let
  pkgs = import <nixpkgs> {};
  configuration = { lib, pkgs, config, modulesPath, ... }: let
  in {
    imports = [
      ./nixos.nix
      ./installer.nix
    ];

    services.openssh.enable = true;
    networking.useNetworkd = true;
    environment.systemPackages = [ pkgs.vim ];

    systemd.network.networks.venet0 = {
      name = "venet0";
      address = [ "10.10.20.156/32" ];
      networkConfig = {
        DHCP = "no";
        DefaultRouteOnDevice = "yes";
        ConfigureWithoutCarrier = "yes";
      };
    };
  };
  nixos = pkgs.nixos configuration;
in nixos.config.system.build.toplevel
#in nixos.config.system.build.firstTimeInit
#in nixos.config.system.build.tarball
