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
, unholyExpression
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
, keepBuildImage ? false
# the default behaviour in docker is to prune
# all the untagger parent layers
, pruneUntaggedParents ? true
, nixBinaryInstaller ? null
, nixBinaryInstallerComp ? null
, dockerExec ? "/usr/bin/docker"
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

  defaultNixInstaller = fetchurl {
    url = https://nixos.org/releases/nix/nix-2.2.1/nix-2.2.1-x86_64-linux.tar.bz2;
    sha256 = "1q3rr8g8fi92xlvw504j4fnlxsr4gaq0g44c4x66ib8c4n7y4ag2";
  };

  nixInstaller = (
    if nixBinaryInstaller == null then
     defaultNixInstaller
    else nixBinaryInstaller
  );

  nixInstallerComp = (
    if nixBinaryInstallerComp == null then
     ".tar.bz2"
    else nixBinaryInstallerComp
  );
in
  mkBuild {
    inherit name;
    scriptPath = ./base-builder.sh;
    buildInputs = with pkgs; [ gnutar gnugrep bzip2 ];
    allowedSystemCmds = [
      dockerExec
    ];
    directAttrs = {
      inherit
         unholyExpression buildArgs
         keepBuildImage pruneUntaggedParents
         nixInstaller nixInstallerComp
         targetSystemBuildDependencies
         targetSystemRunDependencies;
      dockerFile = ./dockerfiles + "/${ targetSystem }/Dockerfile";
      entryPoint = ./dockerfiles + "/${ targetSystem }/entrypoint.sh";
      buildScript = ./dockerfiles + "/${ targetSystem }/build.sh";
    } // specialUnholyValues;
  }
