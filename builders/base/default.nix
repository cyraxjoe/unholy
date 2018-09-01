{ pkgs, utils }:
rec {
 inherit pkgs; # reference for the base nixpkgs
 inherit (utils) bigErrorMsg;

 mkBuild =
  { name ? "unknown"
   , script ? null
   , scriptPath ? null
   , allowedSystemCmds ? []
   , buildInputs ? []
   , namePrefix ? "ci-build"
   , impureBuild ? true
   , envVars ? {}
   , passThru ? {} }:
   assert (script == null && scriptPath == null) ->
      abort (bigErrorMsg "Missing 'script' or 'scriptPath' parameter.");
   assert (script != null && scriptPath != null) ->
      abort (bigErrorMsg "You have to define either 'script' or 'scriptPath', not both.");
   let
     inherit(pkgs) system bash coreutils moreutils gnused;
     inherit(pkgs.lib)
       optional optionalAttrs concatStringsSep makeOverridable
       mapAttrs' nameValuePair strings;
     inherit(builtins) currentTime;

     coreAttributes = {
       inherit system allowedSystemCmds;
       name = "${ namePrefix }-${name}";
       builder = "${ bash }/bin/bash";
       args = [ ./base-builder.sh ];
       stdenvUtilsPath = ./stdenv-utils.sh;
       passAsFile = [ "setupEnv" ] ++ optional (script != null) "script";
       inputPath =
         let
           binPaths = map (pkg: "${ pkg }/bin") buildInputs;
         in
           concatStringsSep ":" binPaths;
       setupEnv = ''
          PATH="${ bash }/bin/:${ coreutils }/bin/:${ moreutils }/bin:${ gnused }/bin:$inputPath"
          if [[ -n $allowedSystemCmds ]]; then
              _TEMP_PATH="$(pwd)/.build_path"
              mkdir $_TEMP_PATH
              for cmd in $allowedSystemCmds; do
                  full_cmd=$(readlink -e $cmd)
                  base_name=$(basename $cmd)
                  ln -s $full_cmd $_TEMP_PATH/$base_name
              done
              PATH="$PATH:$_TEMP_PATH"
          fi
          export PATH
       '';
     };
     environmentVariables =
       mapAttrs' (name: value:
                   nameValuePair "ENV_${strings.toUpper name}" value)
                 envVars;
   in
     makeOverridable derivation (
       coreAttributes
            // environmentVariables
            # make sure we modify the build inputs so we can guarantee that the
            # build is going to be executed, we are not looking for purity here.
            // optionalAttrs (impureBuild == true) { variant = builtins.currentTime; }
            // optionalAttrs (script != null) { inherit script; }
            // optionalAttrs (scriptPath != null) { inherit scriptPath; }
            // passThru

     );
}
