{ callPackage  }:
{
 mkPythonVirtualEnv = callPackage ./virtualenv { };
 mkPythonVenvFromPypi = callPackage ./virtualenv_from_pypi.nix { };
}
