# TODO: need to add an input for additional PPAs, e.g. the deadsnakes PPA
# to be used for python builds

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
, nixVoyagerScript
, nixVoyagerExpressionArgs ? {}
, targetSystem ? "ubuntu-16.04"
, targetSystemRepos ? []
, targetSystemAptKeys ? []
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
# the default behaviour in docker is to prune
# all the untagger parent layers
, pruneUntaggedParents ? true
, dockerExec ? "/usr/bin/docker"
, logExecution ? false
, namePrefix ? null
, outputs ? [ "out" ]
, meta ? {}
, envVars ? {}
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
            voyagerIntegerPrefix;
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
