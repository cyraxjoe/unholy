{ builders, pythonPackages }:
# helper function that wraps on top of mkPythonVirtualEnv
# to create virtualenvs directly from a package in PyPI
{ name, version, sha256, systemPython ? "/usr/bin/python" }:
let
  inherit(pythonPackages) fetchPypi;
  inherit(builders) mkPythonVirtualEnv;
  mainPackageName = "${ name }-${ version}";
  pname = name; # expected attribute name for fetchPypi
in
mkPythonVirtualEnv {
   name = mainPackageName;
   src = fetchPypi { inherit pname version sha256; };
   inherit mainPackageName systemPython;
}
