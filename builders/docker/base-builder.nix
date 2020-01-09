{ pkgs
, fetchurl
, lib
, builders
, utils }:
let
   inherit (builders) mkBuild;
   inherit (builtins) elemAt toString attrNames any hasAttr isInt;
   inherit (lib) splitString optional lists mapAttrsToList hasPrefix removePrefix;
   inherit (utils) bigErrorMsg;
in
{ name

# the build script to run in the container.
# be sure to use `set -e` (fail on first error) and `set -u` (fail on unset
# env variables) in your scripts. this will get you better output earlier on
# in the build.
, nixVoyagerScript

# any nix inputs or other args that should be made available in the container.
# these will be translated from nix to a container representation using
# the configureBuildArgument function in base-builder.sh
, nixVoyagerExpressionArgs ? {}

# if you have args that you want to pass through without any translation layer
# (e.g. if it's a file path it won't be treated as a file and copied into the
# container), you can set them here. the `nixVoyagerScript` will have access
# to these variables
, envVars ? {}

# currently only ubuntu 16.04 is supported
, targetSystem ? "ubuntu-16.04"

# an optional list of string names of debian repos. these will be added
# to the container, and apt-get update will be run, prior to running your build.
# use \ to quote spaces.
# ex: adding the maria db repo
# targetSystemRepos =
#  [ "'deb\ http://sfo1.mirrors.digitalocean.com/mariadb/repo/10.2/ubuntu\ xenial\ main'" ];
, targetSystemRepos ? []

# keys to be imported by apt-key
# ex. adding the maria db public key
# targetSystemAptKeys = [ "0xF1656F24C74CD1D8" ];
, targetSystemAptKeys ? []

# a list of packages to apt-get install so they will be available to your
# build environment. if you need something not in the default repos you
# can use targetSystemRepos and targetSystemAptKeys to add extra PPAs or
# custom repos
, targetSystemBuildDependencies ? []

# currently we are not doing anything with this attribute
# but as a TODO: build a script for each target system that
# verifies that the system has the expected (manually specified)
# runtime dependencies (e.g. using
# dpkg-query --show --showformat='${db:Status-Status}\n' '<pkg>'
# dpkg-query --show --showformat='${Version}\n' '<pkg>')
, targetSystemRunDependencies ? []

# refer to the root of the nix-voyager lib, we are going to copy over
# this directory into the docker container
, nixVoyagerSrc ? ../../.

# this will cause to run docker build with "--force-rm" to ensure
# that a potential failure in the build does not left a container
# as a side-effect on the system.
# If is set to "false" and potentially accumulate some stopped
# containers in the system you can remove those with "docker rm"
, alwaysRemoveBuildContainers ? true

# if set to false, use --no-cache in the docker build process,
# this will prevent storing any intermediate image as part of the build
# process
, noBuildCache ? false

# keep the resulting build image in case of success
, keepBuildImage ? false

# the default behaviour in docker is to prune all the untagged parent layers
, pruneUntaggedParents ? true

# path to use for the docker binary
, dockerExec ? "/usr/bin/docker"

# additional logging that will be visible by hydra at the end of the build
, logExecution ? false

, namePrefix ? null
, outputs ? [ "out" ]
, meta ? {}

}:

#######################
# Argument verification
#######################
let
  restrictedNames = {
    storePath = "This attribute will be set at build time";
    nixVoyagerSrc = "Used to pass the nix-voyager library into the build";
  };
  names = attrNames  nixVoyagerExpressionArgs;
in
assert (bigErrorMsg (! (any (n: hasAttr n restrictedNames) names)) ''
  Invalid argument in 'nixVoyagerExpressionArgs':
     Provided: [ ${ toString names } ]
     Restricted: [ ${ toString (attrNames restrictedNames) } ]'');
########################
let
  # TODO: use these two to determine if we can share files
  # to avoid duplication in the dockerfiles
  osName = elemAt (splitString "-" targetSystem) 0;

  osVersion = elemAt (splitString "-" targetSystem) 1;

  # special values to be able to replicate the arguments inside the
  # docker nix-build call
  voyagerTrueValue = "_voyager_true_value_";

  voyagerFalseValue = "_voyager_false_value_";
  #
  voyagerNullValue = "_voyager_null_value_";
  #
  voyagerEmptyStringValue = "_voyager_empty_string_value_";
  #
  voyagerIntegerPrefix = "_voyager_integer";
  #
  voyagerPathListPrefix = "_voyager_path_list_";
  #
  transformToVoyagerInteger = val:
    "${ voyagerIntegerPrefix }:${ toString val }";
  #
  specialNixVoyagerValues = {
    inherit voyagerTrueValue voyagerFalseValue
            voyagerNullValue voyagerEmptyStringValue
            voyagerIntegerPrefix voyagerPathListPrefix;
  };

  # pretty sad implementation.. but does the trick,
  # to provide special strings to determine
  # what was the original value
  # TODO: maybe use a nix set for these vars and require callers
  # to specify the types for decoding
  getShellSafeValue = val:
     if val == null
     then voyagerNullValue
     else (if val == ""
           then voyagerEmptyStringValue
           else (if val == false
                 then voyagerFalseValue
                 else (if val == true
                       then voyagerTrueValue
                       else (if (isInt val) == true
                             then transformToVoyagerInteger val
                             else val))));

  buildArgs =
   lists.flatten (
       mapAttrsToList (name: value:  [ name (getShellSafeValue value) ])
          (nixVoyagerExpressionArgs // { inherit nixVoyagerSrc; })
  );

  passThruEnv =
   lists.flatten (
       mapAttrsToList (name: value:  [ name (getShellSafeValue value) ])
          envVars
  );

in

  # mkBuild is the base builder from <nix voyager>/builders/base
  mkBuild {
    inherit name logExecution meta namePrefix outputs;
    scriptPath = ./base-builder.sh;
    buildInputs = with pkgs; [ gnutar gnugrep bzip2 ];
    allowedSystemCmds = [
      dockerExec
    ];
    directAttrs = {
      inherit
         nixVoyagerScript buildArgs passThruEnv
         alwaysRemoveBuildContainers noBuildCache
         keepBuildImage pruneUntaggedParents
         targetSystemBuildDependencies
         targetSystemRunDependencies
         targetSystemRepos targetSystemAptKeys;
      dockerFile = ./dockerfiles + "/${ targetSystem }/Dockerfile";
      entryPoint = ./dockerfiles + "/${ targetSystem }/entrypoint.sh";
      buildScript = ./dockerfiles + "/${ targetSystem }/build.sh";
    } // specialNixVoyagerValues;
  }
