{ builders, pythonPackages }:
# helper function that wraps on top of mkPythonVirtualEnv
# to create virtualenvs directly from a package in PyPI
{ name
, version
, sha256
, ... } @ args:
let
  inherit(builtins) removeAttrs;
  inherit(pythonPackages) fetchPypi;
  inherit(builders) mkPythonVirtualEnv;
  mainPackageName = "${ name }-${ version}";
  pname = name; # expected attribute name for fetchPypi
  extraArgs =  removeAttrs args [
    "name"  "version" "sha256"
  ];
in
mkPythonVirtualEnv ({
   name = mainPackageName;
   inherit mainPackageName;
   mainPackageSrc = fetchPypi {
     inherit pname version sha256;
   };
} // extraArgs)
