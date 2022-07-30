{ lib, pkgs, config, ... }:
let
  # With most out-of-box templates, OpenVZ automatically runs a set of bash scripts
  # in the guest container every boot to customize the system (setting hostname, IP
  # addresses, etc.). We can't run them in NixOS, but they have to be successfully
  # executed for the container to boot :(
  #
  # Here we use an ugly hack to silently ignore the scripts. Note that `vzctl enter`
  # as well as the "Serial Console" feature in SolusVM also hard-depend on /bin/bash.
  binBashWrapper = pkgs.writeShellScript "bash" ''
    if [[ "$(${pkgs.coreutils}/bin/tr -d '\0' </proc/1/cmdline)" == *"vzctl"* ]]; then
        # PID 1 is vzctl - Refuse to run OpenVZ provider script
        exit 0
    fi

    exec ${pkgs.bashInteractive}/bin/bash "$@"
  '';
in {
  boot.isContainer = true;
  boot.loader.initScript.enable = true;
  boot.specialFileSystems."/run/keys".fsType = lib.mkForce "tmpfs";

  boot.postBootCommands = ''
    # After booting, register the contents of the Nix store in the Nix
    # database.
    if [ -f /nix-path-registration ]; then
      ${config.nix.package.out}/bin/nix-store --load-db < /nix-path-registration &&
      rm /nix-path-registration
    fi

    # nixos-rebuild also requires a "system" profile
    if [ ! -e /nix/var/nix/profiles/system ]; then
      ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
    fi

    # Create /dev/net/tun. It is done automatically in most cases, but for some
    # hosts it's not there.
    mkdir -p /dev/net
    mknod /dev/net/tun c 10 200
  '';

  systemd.extraConfig = ''
    [Service]
    ProtectProc=default
    ProtectControlGroups=no
    ProtectKernelTunables=no
  '';

  # systemd-udev-trigger.service is suppressed when boot.isContainer is true.
  # This is required for networkd to work properly.
  #
  # We manually create an identical unit under a different name to avoid
  # conflict.
  systemd.services.systemd-udev-trigger-ovz = {
    description = "Coldplug All udev Devices";
    after = [ "systemd-udevd-kernel.socket" "systemd-udevd-control.socket" ];
    wants = [ "systemd-udevd.service" ];
    wantedBy = [ "sysinit.target" ];
    unitConfig = {
      DefaultDependencies = "no";
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      ExecStart = [
        "-udevadm trigger --type=subsystems --action=add"
        "-udevadm trigger --type=devices --action=add"
      ];
    };
  };

  networking.useHostResolvConf = false;
  networking.firewall.package = lib.mkDefault pkgs.iptables-legacy;

  system.build.binBashWrapper = binBashWrapper;
  system.activationScripts.injectOpenVzScripts = ''
    mkdir -p /sbin
    if [ ! -f /sbin/init ]; then
      ln -sf $systemConfig/init /sbin/init
    fi
    ln -sf ${pkgs.quota}/bin/quotaon /sbin/quotaon

    ln -sf ${binBashWrapper} /bin/bash
    touch /fastboot
  '';
}
