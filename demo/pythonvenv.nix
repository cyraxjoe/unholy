{ unholy ? (import ../default.nix {}) }:
with unholy.builders;
let
  makeVenv =
  { pname, version, sha256, systemPython ? "/usr/bin/python" }:
  {"${ pname }" =
      let
        name = "${ pname }-${ version}";
      in mkPythonVirtualEnv {
         inherit name systemPython;
         src = pkgs.pythonPackages.fetchPypi {
           inherit pname version sha256;
         };
      };
   };

in
builtins.foldl' (a: b: a // b) {} [
   (makeVenv { pname = "awake";
               version = "1.0";
               sha256 = "a4be9058c08ed702b700c9e10e270a7355ba1563f22ad6b2dbd334c6bb5a1730"; })
   (makeVenv { pname ="docker-compose";
               version = "1.22.0";
               sha256 = "915cdd0ea7aff349d27a8e0585124ac38695635201770a35612837b25e234677"; })
   (makeVenv { pname = "ipython";
               version =  "6.5.0";
               sha256 = "b0f2ef9eada4a68ef63ee10b6dde4f35c840035c50fd24265f8052c98947d5a4";
               systemPython = "/usr/bin/python3"; })
   (makeVenv { pname = "bpython";
               version = "0.17.1";
               sha256 = "8907c510bca3c4d9bc0a157279bdc5e3b739cc68c0f247167279b6fe4becb02f";})
   # { local-package =
   #   let
   #      localPackageDep =
   #        { name = "local-package-dep";
   #          src = /local/path/to/dir; };
   #   in
   #    mkPythonVirtualEnv {
   #       name = "local-package";
   #       systemPython = "/usr/bin/python3";
   #       src = /local/path/to/src; # (or use fetch url)
   #       exposedCmds = [ "my-cmd" ];
   #       preLoadedPythonDepList = [ localPackageDep ];
   #    };
   #  }
]
