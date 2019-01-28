{ pkgs , fetchurl, lib , builders }:
let
   inherit (builtins) removeAttrs;
   inherit (lib) lists;
   inherit (lib.attrsets) attrNames;
   ##############################
   inherit (builders) mkBuild;
in
{ mainPackageName
, src
, name
, namePrefux ? null
, installDepsFromRequires ? ""
, systemPython ? "/usr/bin/python"
, virtualEnvSrc ? null
, preLoadedPythonDeps ? []
, exposedCmds ? []
, useBinaryWheels ? false
, namePrefix ? null
, logExecution ? false
# define this parameter to create the venv on this path,
# useful to build the venv inside a docker container
, storePath ? ""
# this attribute is for small experiments...
# don't rely a lot on it
, extraDirectAttrs ? {}
, debugBuild ? false
}:
let
  defaultVirtualEnvSrc = fetchurl {
     url = "https://pypi.io/packages/source/v/virtualenv/virtualenv-16.2.0.tar.gz";
     sha256 = "1ka0rlwhcsqkv995jr1xfglhj9d94avbwippxszx52xilwqnhwzs";
  };

  virtualEnvTar = (
    if virtualEnvSrc == null
    then defaultVirtualEnvSrc
    else virtualEnvSrc);

  preparedPythonDeps = lists.flatten
    (map (d: [ d.name d.src ]) preLoadedPythonDeps);

  directAttrs = {
    preLoadedPythonDeps = preparedPythonDeps;
    inherit
      exposedCmds
      virtualEnvTar
      systemPython
      mainPackageName src
      useBinaryWheels
      installDepsFromRequires
      storePath;
  } // extraDirectAttrs;
in
mkBuild {
  inherit name namePrefix logExecution directAttrs debugBuild;
  allowedSystemCmds = [
    # the lsb_release from nix doesn't detect the "Distribution ID"
    # and it doesn't work with the linux distribution detection in pip
    "/usr/bin/lsb_release"
    # dpkg-query is an implicit dependency for lsb_release, otherwise
    # it fails in ubuntu
    "/usr/bin/dpkg-query"
    #
    "/usr/bin/ldd"
    "/usr/bin/gcc"
  ];
  buildInputs = with pkgs; [
    gnutar gzip gnugrep
    file findutils
  ];
  scriptPath = ./python-venv-builder.sh;
 }
