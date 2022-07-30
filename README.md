# NixOS on OpenVZ 7

Configurations needed to run NixOS on OpenVZ 7 VPSes created with the Debian/Ubuntu template.

This repo is only useful if you are an end-user without access to the host and it's unreasonable to request configuration changes on the host.
If you are the provider, please [create a new distribution config](https://discourse.nixos.org/t/nixos-as-openvz-7-guest/10683/2) that does not attempt to manipulate the guest configurations.

## Usage

Create a `configuration.nix`:

```nix
{
  networking.useNetworkd = true;

  systemd.network.networks.venet0 = {
    name = "venet0";
    # Change to your assigned IP
    address = [ "10.10.10.123/32" ];
    networkConfig = {
      DHCP = "no";
      DefaultRouteOnDevice = "yes";
      ConfigureWithoutCarrier = "yes";
    };
  };

  services.openssh.enable = true;

  users.users.root.openssh.authorizedKeys.keyFiles = [
    # ...
  ];
}
```

Next, build the tarball that contains the bootstrap configuration:


```
nix-build generate-openvz-tarball.nix --arg configuration ./configuration.nix
```

Upload the tarball to the VPS, then extract it onto the root filesystem:

```
tar xpf nixos-system-x86_64-linux.tar.xz -C /
reboot -f
```

The VPS will reboot into NixOS, with existing files in the root filesystem moved into `/old-root`.
You can delete the directory to save space.
When rebuilding, include `./nixos.nix` in your NixOS configuration.

## Tested Providers

- [Gullo's Hosting](https://hosting.gullo.me)
- [Inception Hosting](https://inceptionhosting.com)
- [EthernetServers](https://www.ethernetservers.com)

## FAQ

### Why is this needed?

With most out-of-box templates, OpenVZ automatically runs a set of bash scripts in the guest container prior to every boot to customize the system (setting hostname, IP addresses, etc.).
We can't run them in NixOS, but the scripts have to be successfully executed for the container to boot :(

Here we silently ignore the scripts with an ugly hack, which is a `/bin/bash` wrapper that refuses to do anything if PID 1 is `vzctl`.
Note that `vzctl enter` as well as the "Serial Console" feature in SolusVM also hard-depend on `/bin/bash`.

### Will this work on OpenVZ 6?

No, because the kernel is too old to start systemd.
Please do not buy such VPSes no matter how cheap they may be.
