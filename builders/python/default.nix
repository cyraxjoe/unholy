{ pkgs, builders, utils }:
let
   inherit (builtins) removeAttrs getAttr;
   inherit (utils) bigErrorMsg;
   inherit (builders) mkBuild;
   inherit (pkgs) fetchurl;
   inherit (pkgs.lib) lists;
in
{
  mkPythonVirtualEnv =
   { src
   , systemPython ? "/usr/bin/python"
   , virtualEnvSrc ? null
   , preLoadedPythonDepList ? []
   , exposedCmds ? []
   , ...} @ args:
   let
      mkBuildArgs = removeAttrs args [
         "src" "systemPython"
         "virtualEnvSrc"
         "preLoadedPythonDepList"
         "exposedCmds"
      ];
      virtualEnvTar = (
       if virtualEnvSrc != null
         then  virtualEnvSrc
       else  fetchurl {
         url = "https://pypi.io/packages/source/v/virtualenv/virtualenv-16.0.0.tar.gz";
         sha256 = "0lpp31kwjmfyzmgdmbsps4inj08bg4chjkgkz4daj52fnp0b81ya";
       });

       coreAttributes = {
         namePrefix = null;
         allowedSystemCmds = [
         "/usr/bin/lsb_release"
         "/usr/bin/dpkg-query" # dependency of lsb_release
         "/bin/uname"];
         buildInputs = with pkgs; [ gnutar gzip which ];
         scriptPath = ./python-venv-builder.sh;
         passThru = {
          inherit src systemPython virtualEnvTar exposedCmds;
          preLoadedPythonDeps = lists.flatten (
           map (d: [ d.name d.src ]) preLoadedPythonDepList);
         };

       };
    in
       mkBuild (coreAttributes // mkBuildArgs);

  mkPythonBuild =
   { src
   , requirementsPath ? "requirements.txt"
   , usePython2 ? false
   , useSystemVirtualEnv ? true
   , ...}@args:
    let
      inherit(pkgs) gcc;
      typeOfVEnv = if useSystemVirtualEnv then "system" else "embedded";
      typeOfPython = if usePython2 then "python2Packages" else "python3Packages";
      pyPrefix = if usePython2 then "py2" else "py3";
      pythonPackages = getAttr typeOfPython pkgs;

      makeVEnvScripts = {
         system = ./make-system-virtualenv.sh;
         embedded = ./make-virtualenv.sh;
      };
      mkBuildArgs = removeAttrs args [
         "src" "useSystemVirtualEnv"
         "useSystemVirtualEnv" "requirementsPath"
      ];
      coreAttributes = rec {
        namePrefix = "${ pyPrefix }-build";
        allowedSystemCmds = [ "/usr/bin/git" "/usr/bin/ssh" ];
        buildInputs =  [ gcc pythonPackages.virtualenv ];
        envVars = {
          requirements = requirementsPath;
        };
        passThru = {
          inherit src;
          makeVirtualEnvScript = getAttr typeOfVEnv makeVEnvScripts;
        };
        scriptPath = ./python-builder.sh;
      };
    in
     mkBuild (mkBuildArgs // coreAttributes);


}
