{ pkgs
, lib
, builders }:
let
   inherit (builders) mkBuild;
   inherit (builtins) toPath elemAt toString;
   inherit (lib) splitString optional;
in
{
  name
, unholyExpression
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
, useSudo ? false
, sudoUser ? ""
, keepBuildImage ? false
}:
let
  # TODO: use these two to determine if we can share files
  # to avoid duplication in the dockerfiles
  osName = elemAt (splitString "-" targetSystem) 0;
  osVersion = elemAt (splitString "-" targetSystem) 1;
in
  mkBuild {
    inherit name;
    scriptPath = ./base-builder.sh;
    buildInputs = with pkgs; [ gnutar gnugrep ];
    allowedSystemCmds = [
      "/usr/bin/docker"
    ] ++ optional useSudo "/usr/bin/sudo";
    directAttrs = {
      inherit unholySrc unholyExpression
         useSudo sudoUser keepBuildImage
         targetSystemBuildDependencies
         targetSystemRunDependencies;
      dockerFile = ./dockerfiles + "/${ targetSystem }/Dockerfile";
      entryPoint = ./dockerfiles + "/${ targetSystem }/entrypoint.sh";
      buildScript = ./dockerfiles + "/${ targetSystem }/build.sh";
    };
  }
