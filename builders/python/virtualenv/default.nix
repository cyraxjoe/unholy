{ pkgs , fetchurl, lib , builders }:
let
   inherit (builtins) removeAttrs;
   inherit (lib) lists;
   inherit (lib.attrsets) attrNames;
   ##############################
   inherit (builders) mkBuild _mkFindLinksDir;
in
{
# name of the virtual environment
  name
# string to be used a prefix to the name,
# if is set to null, then the resulting name
# will be based solely on the `name` parameter
, namePrefix ? "venv"
##################################
##########
# requires = {
#   # list of requires files, if the requires file has a sha256
#   # in the requires format "name==<version> --hash sha256:<hash-value>"
#   # it will use that as a refernce when we pull the dependences from pypi
#   files = [];
#   # This has to be either a directory or a url pointing to
#   # some location to obtain the dependencies.
#   # Both lists are related by the position on the list
#   findLinks = [];
# }
##########
, requires ? { files = []; findLinks = []; }
###
# same as the previous "requires" parameter, but for the
# virtualenv required to build the wheels before they are installed
# in the virtualenv
, buildRequires ? { files = []; findLinks = []; }
# optionally specify a "mainPackageSrc", a directory or tar.gz
# with a project to be installed in addition to the requires file
, mainPackageSrc ? null
# identified of the project defined in mainPackageSrc
, mainPackageName ? null
# additional directories or tar.gz with dependencies
# obtained from other methods and are going to be installed
# in the virtualenv, any dependencies required by any of this
# project should be provided, it should be a list of
# attribute sets with "name" and "src" keys for example:
#  { name = "awake";
#    src = fetchurl { url = "someurl"; sha256 = "somehash"; };}
# or
#  { name = "awake";
#    src = /home/user/some-checkout;}
, preLoadedPythonDeps ? []
##################################
# full path to the python executable in the system, that's
# going to be used to build the virtualenv
, systemPython ? "/usr/bin/python"
# if defined, it should point into a tar.gz of virtualenv
, virtualEnvSrc ? null
# list of command that will be exposed from the environment bin
# folder into the top bin folder of the derivation
, exposedCmds ? []
# keep a log of all the verbose ouput of the execution
# of the building process under var/log/
, logExecution ? false
# define this parameter to create the venv on this path,
# useful to build the venv inside a docker container
, storePath ? ""
# this attribute is for small experiments...
# don't rely a lot on it, you can pass some additional
# attributes to be available on the builder as environment variables
# but... if you are already doing that you should consider either
# extend this derivation or start a new one based on mkBuild
, extraDirectAttrs ? {}
# extra verbose ouput on the execution of the build
, debugBuild ? false
# meta attributes, similar to the ones used in nixpkgs
, meta ? {}
}:
let
  makeFindLinkDirs = requiresFiles:
    map (r: _mkFindLinksDir { projectName = name; requiresFile = r; }) requiresFiles;

  makeFindLinks = r:
    if (r.files or [] == [])
    then []
    # if we have requires but no findLinks, then we create that
    # directory based on the requires file using makeFindLinkDirs
    else (if (r.findLinks or [] == [])
          then makeFindLinkDirs r.files
          else r.findLinks or []);

  defaultVirtualEnvSrc = fetchurl {
     url = "https://pypi.io/packages/source/v/virtualenv/virtualenv-16.3.0.tar.gz";
     sha256 = "729f0bcab430e4ef137646805b5b1d8efbb43fe53d4a0f33328624a84a5121f7";
  };

  virtualEnvTar = if virtualEnvSrc == null
                  then defaultVirtualEnvSrc
                  else virtualEnvSrc;

  directAttrs = {
    # the pre-loaded python dependencies pre formated as pairs
    # on a space separated list/bash array
    preLoadedPythonDeps = lists.flatten
    (map (d: [ d.name d.src ]) preLoadedPythonDeps);
    # these two are interelated
    requiresFiles = requires.files;
    findLinks = makeFindLinks requires;
    ###
    # these two are interelated
    buildRequiresFiles = buildRequires.files;
    buildFindLinks = makeFindLinks buildRequires;
    ###
    inherit
      exposedCmds
      virtualEnvTar
      systemPython
      mainPackageName
      mainPackageSrc
      storePath;
  } // extraDirectAttrs;
in
mkBuild {
  inherit name namePrefix logExecution directAttrs debugBuild meta;
  outputs = [ "out" "wheels" ];
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
    gnutar gzip gnugrep gawk file findutils
  ];
  scriptPath = ./python-venv-builder.sh;
 }
