{ pkgs , fetchurl, lib , builders }:
{ mainPackageName
, src
, installDepsFromRequires ? ""
, systemPython ? "/usr/bin/python"
, virtualEnvSrc ? null
, preLoadedPythonDeps ? []
, exposedCmds ? []
, useBinaryWheels ? false
, namePrefix ? null
, ...} @ args:
let
   inherit (builtins) removeAttrs;
   inherit (lib) lists;
   inherit (lib.attrsets) attrNames;
   ##############################
   inherit (builders) mkBuild;

  defaultVirtualEnvSrc = fetchurl {
     url = "https://pypi.io/packages/source/v/virtualenv/virtualenv-16.0.0.tar.gz";
     sha256 = "0lpp31kwjmfyzmgdmbsps4inj08bg4chjkgkz4daj52fnp0b81ya";
   };

  virtualEnvTar = (
    if virtualEnvSrc != null
      then  virtualEnvSrc
    else  defaultVirtualEnvSrc
  );


  coreAttributes = {
    namePrefix = args.namePrefix or null;
    allowedSystemCmds = [
      "/usr/bin/ldd"
      "/usr/bin/lsb_release"
      "/usr/bin/dpkg-query" # dependency of lsb_release
      "/usr/bin/gcc"
      "/bin/uname"
    ];
    buildInputs = with pkgs; [
      gnutar gzip which file findutils
      coreutils gnugrep
    ];
    scriptPath = ./python-venv-builder.sh;
    directAttrs = {
      preLoadedPythonDeps = lists.flatten (map (d: [ d.name d.src ]) preLoadedPythonDeps);
      inherit mainPackageName src systemPython virtualEnvSrc
              exposedCmds useBinaryWheels virtualEnvTar
              installDepsFromRequires;
    };
  };

  mkBuildArgs = removeAttrs args (attrNames coreAttributes.directAttrs);
in
   mkBuild (coreAttributes // mkBuildArgs)
