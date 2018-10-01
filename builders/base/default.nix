{ pkgs, lib, utils }:
let
 mkBuild =
  { name ? "unknown"
   , script ? null
   , scriptPath ? null
   , allowedSystemCmds ? []
   , buildInputs ? []
   , namePrefix ? "unholy"
   , ensureRebuild ? false
   , envVars ? {}
   , directAttrs ? {}
   , passThru ? {}
   , meta ? {} }:
   let
    inherit (pkgs) bash system;
    inherit(pkgs.lib)
      optionalAttrs concatStringsSep  mapAttrs' nameValuePair strings;
    coreAttributes = {
      inherit system;
      inherit allowedSystemCmds;
      name = (if namePrefix == null
              then name
              else "${ namePrefix }-${name}");
      builder = "${ bash }/bin/bash";
      passAsFile = [ "setupEnv" "script"];
      args = [ ./base-builder.sh ];
      stdenvUtilsPath = ./stdenv-utils.sh;
      inputPath =
        let
          binPaths = map (pkg: "${ pkg }/bin") buildInputs;
        in
          concatStringsSep ":" binPaths;
      setupEnv = with pkgs;
      ''
         PATH="${ bash }/bin/:${ coreutils }/bin/:${ moreutils }/bin:${ gnused }/bin:$inputPath"
         if [[ -n $allowedSystemCmds ]]; then
             _TEMP_PATH="$(pwd)/.build_path"
             mkdir $_TEMP_PATH
             set +e
             for cmd in $allowedSystemCmds; do
                 full_cmd=$(readlink -e $cmd)
                 if (( $? != 0 )); then
                     echo "The command '$cmd' is not present in the system. Ignoring" > /dev/stderr
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
    };

    # transform the explicitly passed attribute set to be used as environment variable
    # from "foo" to "ENV_FOO"
    environmentVariables =
      mapAttrs' (name: value:
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
             assert (scriptPath == null) ->
               throw (utils.bigErrorMsg "Missing 'script' or 'scriptPath' parameter.");
             # We are been explicitly wasteful by reading the input script when the
             # user provides a path, small trade-off to make it consistent on do we
             # create the scriptPath attribute (by using passAsFile)
             { script = builtins.readFile scriptPath; }));
   in
    (derivation derivationArgs) // passThru // { inherit meta; };
in
{ mkBuild = lib.makeOverridable mkBuild;}
