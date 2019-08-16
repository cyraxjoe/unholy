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
   inherit (lib) splitString optional lists mapAttrsToList;
   inherit (utils) bigErrorMsg;
in
{ name
, unholyScript
, unholyExpressionArgs ? {}
, targetSystem ? "ubuntu-16.04"
, targetSystemBuildDependencies ? []
# currently we are not doing anything with this attribute
# but as a TODO: build a script for each target system that
# verifies that the system has the expected (manually specified)
# runtime dependencies (e.g. using
# dpkg-query --show --showformat='${db:Status-Status}\n' '<pkg>'
# dpkg-query --show --showformat='${Version}\n' '<pkg>')
, targetSystemRunDependencies ? []
# refer to the root of the unholy lib, we are going to copy over
# this directory into the docker container
, unholySrc ? ../../.

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
, systemPython ? "/usr/bin/python"
}:

#######################
# Argument verification
#######################
let
  restrictedNames = {
    storePath = "This attribute will be set at build time";
    unholySrc = "Used to pass the unholy library into the build";
  };
  names = attrNames  unholyExpressionArgs;
in
assert (bigErrorMsg (! (any (n: hasAttr n restrictedNames) names)) ''
  Invalid argument in 'unholyExpressionArgs':
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
  unholyTrueValue = "_unholy_true_value_";

  unholyFalseValue = "_unholy_false_value_";
  #
  unholyNullValue = "_unholy_null_value_";
  #
  unholyEmptyStringValue = "_unholy_empty_string_value_";
  #
  unholyIntegerPrefix = "_unholy_integer";
  #
  transformToUnholyInteger = val:
    "${ unholyIntegerPrefix }:${ toString val }";
  #
  specialUnholyValues = {
    inherit unholyTrueValue unholyFalseValue
            unholyNullValue unholyEmptyStringValue
            unholyIntegerPrefix;
  };
  # pretty sad implementation.. but does the trick,
  # to provide special strings to determine
  # what was the original value
  getShellSafeValue = val:
     if val == null
     then unholyNullValue
     else (if val == ""
           then unholyEmptyStringValue
           else (if val == false
                 then unholyFalseValue
                 else (if val == true
                       then unholyTrueValue
                       else (if (isInt val) == true
                             then transformToUnholyInteger val
                             else val))));
  buildArgs =
   lists.flatten (
       mapAttrsToList (name: value:  [ name (getShellSafeValue value) ])
          (unholyExpressionArgs // { inherit unholySrc; })
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
         unholyScript buildArgs
         alwaysRemoveBuildContainers noBuildCache
         keepBuildImage pruneUntaggedParents
         targetSystemBuildDependencies
         targetSystemRunDependencies
         systemPython;
      dockerFile = ./dockerfiles + "/${ targetSystem }/Dockerfile";
      entryPoint = ./dockerfiles + "/${ targetSystem }/entrypoint.sh";
      buildScript = ./dockerfiles + "/${ targetSystem }/build.sh";
    } // specialUnholyValues;
  }
