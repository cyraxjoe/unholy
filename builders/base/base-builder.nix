{ pkgs, lib, utils }:
let
  inherit (pkgs) bash system;
  inherit (lib)
    makeBinPath optionalAttrs concatStringsSep
    mapAttrs' nameValuePair strings;
  inherit (utils) bigErrorMsg;
in
{
# set a default name, in case you just simply don't care...
 name ? "unknown"
# add a name prefix into the builds, to try to distinguish
# the origin of the package, set it to null if you don't want
# to do that.
# The full name will be ${namePrefix}-${name} or just ${name}
# in case namePrefix is null.
, namePrefix ? "unholy"
# mandatory script or scriptPath
, script ? null
, scriptPath ? null
# paths to be symlinked and added into the PATH
# of the build environment
, allowedSystemCmds ? []
# arbitrary list derivations to be added into the PATH
, buildInputs ? []
# add a variation on each build to make sure we execute
# the script, the intention is to force the build because
# we relay in some other inputs obtained externally
, ensureRebuild ? false
# attribute set with environment variables that will be
# prefixed with ENV_ and tranfor to uppercase  the name:
# foo = "bar" -> ENV_FOO="bar"
, envVars ? {}
# arbitrary attributeset to be passed into the build,
# use this attribute to pass custom variables in additional
# builders contructed on top of this
, directAttrs ? {}
# attributeset to be added into the resulting attributeset
# but not to be considered part of the derivation, like
# the metra attribute
, passThru ? {}
# create a logfile with the execution of the build under <pkg>/var/log
# and include it as a hydra-product
, logExecution ? true
# enable bash debug -x just before we execute the main script
, debugBuild ? false
# meta attribute, expecting the same functionality as in the regular nixpkgs,
# e.g. description, license, maintainer, etc.
, meta ? {} }:
let
  coreInputs = with pkgs; [
    bash coreutils moreutils gnused
  ];

  inputPath = makeBinPath (coreInputs ++ buildInputs);

  coreAttributes = {
    name = (
      if namePrefix == null
      then name
      else "${ namePrefix }-${name}");

    builder = "${ bash }/bin/bash";

    passAsFile = [ "setupEnv" "script"];

    args = [ ./base-builder.sh ];

    stdenvUtilsPath = ./stdenv-utils.sh;

    setupEnv = ''
       PATH="$inputPath"
       if [[ -n $allowedSystemCmds ]]; then
           _TEMP_PATH="$(pwd)/.build_path"
           mkdir $_TEMP_PATH
           set +e
           for cmd in $allowedSystemCmds; do
               full_cmd=$(readlink -e $cmd)
               if (( $? != 0 )); then
                   echo "The command '$cmd' is not present in the system. Ignoring" >&2
               else
                   base_name=$(basename $cmd)
                   ln -s $full_cmd $_TEMP_PATH/$base_name
               fi
           done
           set -e
           PATH="$PATH:$_TEMP_PATH"
       fi
       export PATH
    '';
    inherit system allowedSystemCmds logExecution inputPath debugBuild;
  };

  # transform the explicitly passed attribute set to be used as environment variable
  # from "foo" to "ENV_FOO"
  environmentVariables = mapAttrs'
    (name: value:
       nameValuePair "ENV_${strings.toUpper name}" value)
     envVars;

  derivationArgs = (
     coreAttributes
     // environmentVariables
     // directAttrs
     # make sure we modify the build inputs so we can guarantee that the
     # build is going to be executed, we are not looking for purity here.
     // optionalAttrs (ensureRebuild == true) { variant = builtins.currentTime; }
     # give preference to the explicit 'script' parameter, otherwise try to use
     # scriptPath, if none is defined throw an error.
     // (if (script != null) then  { inherit script; }
         else
           assert bigErrorMsg (scriptPath != null)
             "Missing 'script' or 'scriptPath' parameter.";
           # We are been explicitly wasteful by reading the input script when the
           # user provides a path, small trade-off to make it consistent on do we
           # create the scriptPath attribute (by using passAsFile)
           { script = builtins.readFile scriptPath; }));
in
  (derivation derivationArgs) // passThru // { inherit meta; }
