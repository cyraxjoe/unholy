{ pkgs
, fetchurl
, lib
, builders
, utils }:
let
   inherit (builders) mkBuild;
   inherit (builtins) elemAt toString attrNames any hasAttr;
   inherit (lib) splitString optional lists mapAttrsToList;
   inherit (utils) bigErrorMsg;
in
{
  name
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
, nixBinaryInstaller ? null
, nixBinaryInstallerComp ? null
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
  buildArgs =
   lists.flatten (
       mapAttrsToList (name: value:  [ name value ])
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
      "/usr/bin/docker"
    ];
    directAttrs = {
      inherit
         unholyExpression buildArgs keepBuildImage
	 nixInstaller nixInstallerComp
         targetSystemBuildDependencies
         targetSystemRunDependencies;
      dockerFile = ./dockerfiles + "/${ targetSystem }/Dockerfile";
      entryPoint = ./dockerfiles + "/${ targetSystem }/entrypoint.sh";
      buildScript = ./dockerfiles + "/${ targetSystem }/build.sh";
      replaceCustomArgsScript = ./replace_custom_args.py;
    };
  }
