{ pkgs , fetchurl, lib , builders }:
{ src
, systemPython ? "/usr/bin/python"
, virtualEnvSrc ? null
, preLoadedPythonDepList ? []
, exposedCmds ? []
, ...} @ args:
let
   inherit (builtins) removeAttrs;
   inherit (builders) mkBuild;
   inherit (lib) lists;

  mkBuildArgs = removeAttrs args [
     "src" "systemPython"
     "virtualEnvSrc"
     "preLoadedPythonDepList"
     "exposedCmds"
  ];

  defaultVirtualEnvSrc = fetchurl {
     url = "https://pypi.io/packages/source/v/virtualenv/virtualenv-16.0.0.tar.gz";
     sha256 = "0lpp31kwjmfyzmgdmbsps4inj08bg4chjkgkz4daj52fnp0b81ya";
   };

  virtualEnvTar = (
   if virtualEnvSrc != null
     then  virtualEnvSrc
   else  defaultVirtualEnvSrc);

  preLoadedPythonDeps = lists.flatten
     (map (d: [ d.name d.src ]) preLoadedPythonDepList);

  coreAttributes = {
    namePrefix = null;
    allowedSystemCmds = [
      "/usr/bin/lsb_release"
      "/usr/bin/dpkg-query" # dependency of lsb_release
      "/bin/uname"
    ];
    buildInputs = with pkgs; [ gnutar gzip which ];
    scriptPath = ./python-venv-builder.sh;
    passThru = { inherit
      src systemPython virtualEnvTar
      exposedCmds preLoadedPythonDeps;
    };
  };
in
  mkBuild (coreAttributes // mkBuildArgs)
