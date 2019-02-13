{ unholySrc ? ../../../.,}:
let
 unholy = import unholySrc {};
 inherit (unholy.builders) mkDockerBuild pkgs _mkFindLinksDir;
in
mkDockerBuild {
  name = "cherrypy";
  unholyExpression = ./build-cherrypy.nix;
  unholyExpressionArgs = {
     virtualEnvSrc = pkgs.fetchurl {
       url = "https://pypi.io/packages/source/v/virtualenv/virtualenv-16.3.0.tar.gz";
       sha256 = "729f0bcab430e4ef137646805b5b1d8efbb43fe53d4a0f33328624a84a5121f7";
     };
     requires = ./requires.txt;
     findLinks = _mkFindLinksDir {
        projectName = "cherrypy";
        requiresFile = ./requires.txt;
     };
     buildRequires = ./build-requires.txt;
     buildFindLinks = _mkFindLinksDir {
        projectName = "cherrypy-build";
        requiresFile = ./build-requires.txt;
     };

  };
  pruneUntaggedParents = false;
  dockerExec = "/usr/bin/docker";
  targetSystem = "ubuntu-16.04";
  targetSystemBuildDependencies = [
     "ca-certificates" "python3"
  ];

}
