{ lib, pkgs, config, ... }:
let
  firstTimeInit = pkgs.writeShellScript "first-time-init" ''
    systemConfig=${config.system.build.toplevel}
    export PATH=${pkgs.coreutils}/bin

    lustrateRoot () {
        local root="$1"

        echo
        echo -e "\e[1;33m<<< NixOS is now lustrating the root filesystem (cruft goes to /old-root) >>>\e[0m"
        echo

        mkdir -m 0755 -p "$root/old-root.tmp"

        echo
        echo "Moving impurities out of the way:"
        for d in "$root"/*
        do
            [ "$d" == "$root/nix"          ] && continue
            [ "$d" == "$root/boot"         ] && continue # Don't render the system unbootable
            [ "$d" == "$root/old-root.tmp" ] && continue

            mv -v "$d" "$root/old-root.tmp"
        done

        # Use .tmp to make sure subsequent invokations don't clash
        mv -v "$root/old-root.tmp" "$root/old-root"

        mkdir -m 0755 -p "$root/etc"
        touch "$root/etc/NIXOS"

        exec 4< "$root/old-root/etc/NIXOS_LUSTRATE"

        echo
        echo "Restoring selected impurities:"
        while read -u 4 keeper; do
            dirname="$(dirname "$keeper")"
            mkdir -m 0755 -p "$root/$dirname"
            cp -av "$root/old-root/$keeper" "$root/$keeper"
        done

        exec 4>&-
    }

    if [[ -f "/etc/NIXOS_LUSTRATE" ]]; then
        lustrateRoot "/"
    fi

    exec $systemConfig/init
  '';

  lustrateKeepFiles = pkgs.writeText "lustrate-keep-files" ''
    /nix-path-registration
  '';

  fastboot = pkgs.writeText "fastboot" "";
in {
  system.build.tarball = pkgs.callPackage (pkgs.path + "/nixos/lib/make-system-tarball.nix") {
    extraArgs = "--owner=0";

    storeContents = [
      {
        object = config.system.build.toplevel;
        symlink = "none";
      }
      {
        object = firstTimeInit;
        symlink = "/sbin/init";
      }
      {
        object = config.system.build.binBashWrapper;
        symlink = "/bin/bash";
      }
      {
        object = fastboot;
        symlink = "/fastboot";
      }
      {
        object = lustrateKeepFiles;
        symlink = "/etc/NIXOS_LUSTRATE";
      }
    ];

    contents = [
      #{
      #  source = "${config.system.build.toplevel}/init";
      #  target = "/sbin/init";
      #}
    ];

    extraCommands = "mkdir -p proc sys dev";
  };
}
