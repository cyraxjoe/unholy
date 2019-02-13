{ unholySrc
, storePath
, virtualEnvSrc
, requires
, findLinks
, buildRequires
, buildFindLinks
}:
with (import unholySrc {}).builders;
mkPythonVirtualEnv {
  name = "CherryPy";
  systemPython = "/usr/bin/python3";
  exposedCmds = [ "cherryd" ];
  logExecution = false;
  requires = {
    files = [ requires ];
    findLinks = [ findLinks ];
  };
  buildRequires = {
    files = [ buildRequires ];
    findLinks = [ buildFindLinks ];
  };
  inherit storePath virtualEnvSrc;
}
