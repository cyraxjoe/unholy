{ pkgs }:
{ src
, requirementsPath ? "requirements.txt"
, usePython2 ? false
, useSystemVirtualEnv ? true
, ...} @ args:
let
  inherit (builtins) removeAttrs getAttr;
  inherit (pkgs) gcc;
  typeOfVEnv = (if useSystemVirtualEnv
                then "system"
                else "embedded");
  typeOfPython = (if usePython2
                  then "python2Packages"
                  else "python3Packages");
  pyPrefix = if usePython2 then "py2" else "py3";
  pythonPackages = gettAtr typeOfPython pkgs;
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
  mkBuild (mkBuildArgs // coreAttributes)
