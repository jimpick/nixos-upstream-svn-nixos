{system ? __currentSystem}:

rec {

  pkgs = import ./pkgs/top-level/all-packages.nix {inherit system;};

  pkgsDiet = import ./pkgs/top-level/all-packages.nix {
    inherit system;
    bootStdenv = pkgs.useDietLibC pkgs.stdenv;
  };

  pkgsStatic = import ./pkgs/top-level/all-packages.nix {
    inherit system;
    bootStdenv = pkgs.makeStaticBinaries pkgs.stdenv;
  };

  stdenvLinuxStuff = import ./pkgs/stdenv/linux {
    system = pkgs.stdenv.system;
    allPackages = import ./pkgs/top-level/all-packages.nix;
  };


  # The label used to identify the installation CD.
  cdromLabel = "NIXOS";


  # Determine the set of modules that we need to mount the root FS.
  modulesClosure = import ./modules-closure.nix {
    inherit (pkgs) stdenv kernel module_init_tools;
    rootModules = ["ide-cd" "ide-disk" "ide-generic"];
  };


  # Some additional utilities needed in stage 1, notably mount.  We
  # don't want to bring in all of util-linux, so we just copy what we
  # need.
  extraUtils = pkgs.stdenv.mkDerivation {
    name = "extra-utils";
    builder = builtins.toFile "builder.sh"
      "source $stdenv/setup; ensureDir $out/bin; cp $utillinux/bin/mount $utillinux/bin/umount $utillinux/sbin/pivot_root $out/bin; nuke-refs $out/bin/*";
    buildInputs = [pkgs.nukeReferences];
    inherit (pkgsStatic) utillinux;
  };
  

  # The init script of boot stage 1 (loading kernel modules for
  # mounting the root FS).
  bootStage1 = import ./boot-stage-1.nix {
    inherit (pkgs) genericSubstituter;
    inherit (pkgsDiet) module_init_tools;
    inherit extraUtils;
    inherit cdromLabel;
    modules = modulesClosure;
    shell = stdenvLinuxStuff.bootstrapTools.bash;
    staticTools = stdenvLinuxStuff.staticTools;
  };
  

  # The closure of the init script of boot stage 1 is what we put in
  # the initial RAM disk.
  initialRamdisk = import ./make-initrd.nix {
    inherit (pkgs) stdenv cpio;
    packages = [];
    init = bootStage1;
  };


  # The installer.
  nixosInstaller = import ./installer.nix {
    inherit (pkgs) stdenv genericSubstituter nix;
    shell = pkgs.bash + "/bin/sh";
  };


  # The init script of boot stage 2, which is supposed to do
  # everything else to bring up the system.
  bootStage2 = import ./boot-stage-2.nix {
    inherit (pkgs) genericSubstituter coreutils findutils
      utillinux kernel sysklogd udev module_init_tools
      nettools;
    shell = pkgs.bash + "/bin/sh";
    dhcp = pkgs.dhcpWrapper;

    # Additional stuff; add whatever you want here.
    path = [
      pkgs.bash
      pkgs.bzip2
      pkgs.cpio
      pkgs.curl
      pkgs.e2fsprogs
      pkgs.gnugrep
      pkgs.gnused
      pkgs.gnutar
      pkgs.grub
      pkgs.gzip
      pkgs.iputils
      pkgs.less
      pkgs.nano
      pkgs.netcat
#      pkgs.vim
      pkgs.nix
      pkgs.strace
      pkgs.sysvinit
      pkgs.procps
      pkgs.shadowutils
      pkgs.sysklogd
      pkgs.rsync
      pkgs.perl
      nixosInstaller
    ];

    mingetty = pkgs.mingettyWrapper;
  };


  # Since the CD is read-only, the mount points must be on disk.
  cdMountPoints = pkgs.stdenv.mkDerivation {
    name = "mount-points";
    builder = builtins.toFile "builder.sh" "
      source $stdenv/setup
      mkdir $out
      cd $out
      mkdir proc sys tmp etc dev var mnt nix nix/var
      touch $out/${cdromLabel}
    ";
  };


  # Create an ISO image containing the isolinux boot loader, the
  # kernel, the initrd produced above, and the closure of the stage 2
  # init.
  rescueCD = import ./make-iso9660-image.nix {
    inherit (pkgs) stdenv cdrtools;
    isoName = "nixos.iso";
    
    contents = [
      { source = pkgs.syslinux + "/lib/syslinux/isolinux.bin";
        target = "isolinux/isolinux.bin";
      }
      { source = ./isolinux.cfg;
        target = "isolinux/isolinux.cfg";
      }
      { source = pkgs.kernel + "/vmlinuz";
        target = "isolinux/vmlinuz";
      }
      { source = initialRamdisk + "/initrd";
        target = "isolinux/initrd";
      }
      { source = cdMountPoints;
        target = "/";
      }
    ];

    init = bootStage2;
    
    bootable = true;
    bootImage = "isolinux/isolinux.bin";
  };


}
