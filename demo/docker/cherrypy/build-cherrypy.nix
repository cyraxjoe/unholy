{ unholySrc
, storePath
, cherryPySrc
, virtualEnvSrc
}:
with (import unholySrc {}).builders;
mkPythonVirtualEnv {
   mainPackageName = "cherrypy";
   src = cherryPySrc;
   systemPython = "/usr/bin/python3";
   exposedCmds = [ "cherryd" ];
   logExecution = true;
   inherit storePath virtualEnvSrc;
}
