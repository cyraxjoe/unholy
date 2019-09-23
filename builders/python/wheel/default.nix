# python wheel builder that compiles extensions against ubuntu 16.04 libraries

{ pkgs , fetchurl, lib , builders }:
let
   inherit (builtins) removeAttrs;
   inherit (lib) lists;
   inherit (lib.attrsets) attrNames;
   ##############################
   inherit (builders) mkDockerBuild;
in
{
# name of the wheel package
  name

# list of nix derivations containing the python source distribution
, sources

# full path to the python executable in the system, that's
# going to be used to build the virtualenv
, systemPython

, virtualEnvSrc ? null

# this is mainly for specifying alternate debian/ubuntu repos for
# python and its dependencies
, targetSystemRepos ? []

# if you need the public signing key for any of those you can add the
# hex ID of the key here (or anything usable by apt-key).
# e.g. "0xF1656F24C74CD1D8"
, targetSystemAptKeys ? []

, targetSystemBuildDependencies ? null

, extraTargetSystemBuildDependencies ? []
}:

# TODO/discussion item: we could use json structures or declarative bash arrays
# instead of the _voyager_path_list_ prefix below. when we have more than one use
# case we should compare options
mkDockerBuild {
  name = name;

  nixVoyagerScript = ./build_wheel.sh;

  envVars = { inherit systemPython; };
  nixVoyagerExpressionArgs = {
    # the wheel builder is the only builder that needs to construct a list of file paths,
    # but ideally we'll have an importable function to prefix `_voyager_path_list_` in case
    # it ever changes
    sources = "_voyager_path_list_" + builtins.concatStringsSep ":" sources;
    virtualEnvSrc = if (virtualEnvSrc != null) then virtualEnvSrc else  pkgs.fetchurl {
      url = https://files.pythonhosted.org/packages/22/e1/ec3567a4471aa812a3fcf85b2f25e1b79a617da8b1f716ea3a9882baf4fb/virtualenv-16.7.3.tar.gz;
      sha256 = "5e4d92f9a36359a745ddb113cabb662e6100e71072a1e566eb6ddfcc95fdb7ed";
    };
  };
  pruneUntaggedParents = false;
  dockerExec = "/usr/bin/docker";
  # this could also be changed
  targetSystem = "ubuntu-16.04";

  inherit targetSystemRepos targetSystemAptKeys;

  targetSystemBuildDependencies = if (targetSystemBuildDependencies != null) then targetSystemBuildDependencies else [
     "make"
     "gcc"
     "g++"
     "build-essential"
  ] ++ extraTargetSystemBuildDependencies;

  outputs = [ "out" ];

  # debug settings
  alwaysRemoveBuildContainers = true;
  keepBuildImage = false;
}
