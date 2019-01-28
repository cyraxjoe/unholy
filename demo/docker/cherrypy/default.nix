{ unholySrc ? ../../../.,}:
let
 unholy = import unholySrc {};
 inherit (unholy.builders) mkDockerBuild pkgs;
 inherit (pkgs) fetchurl;
in
mkDockerBuild {
  name = "cherrypy";
  unholyExpression = ./build-cherrypy.nix;
  unholyExpressionArgs = {
    virtualEnvSrc = fetchurl {
     url = "https://pypi.io/packages/source/v/virtualenv/virtualenv-16.2.0.tar.gz";
     sha256 = "1ka0rlwhcsqkv995jr1xfglhj9d94avbwippxszx52xilwqnhwzs";
   };
    cherryPySrc = /home/joe/repos/cherrypy;
  };
  pruneUntaggedParents = false;
  dockerExec = "/run/current-system/sw/bin/docker";
  targetSystem = "ubuntu-18.04";
  targetSystemBuildDependencies = [
     "ca-certificates" "git-core"
     "python3" "python3-setuptools" "python3-setuptools-scm"
  ];

}
