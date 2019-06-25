{ unholySrc ? ../../../.
, pharaohSource }:
with (import unholySrc {}).builders;
let
  # these test values are irrelevant for pharaoh
  # OR ARE THEY
  # I do not know
  testValues= {
     falseValue = false;
     trueValue = true;
     nullValue = null;
     emptyStringValue = "";
     zeroValue = 0;
     integerValue = 1560;
     integerAsStringValue = "1000";
  };

in
mkDockerBuild {
  name = "pharaoh_nc";
  mainBuildSource = pharaohSource;
  unholyExpression = ./build-pharaoh.nix;
  unholyExpressionArgs = (testValues // {
     virtualEnvSrc = pkgs.fetchurl {
       url = "https://pypi.io/packages/source/v/virtualenv/virtualenv-16.3.0.tar.gz";
       sha256 = "729f0bcab430e4ef137646805b5b1d8efbb43fe53d4a0f33328624a84a5121f7";
     };
     # these are grouped here because the unholy python builder needs to know the
     # dir the source will be in on the container
     mainPackageName = "pharaoh-nc";
     #mainPackageSrc = containerDirForSource pharaohSource;
     mainPackageSrc = "/home/unholy-user/source/code/pharaoh_nc";
  });
  pruneUntaggedParents = false;
  dockerExec = "/usr/bin/docker";
  targetSystem = "ubuntu-16.04";
  targetSystemBuildDependencies = [
     "python"
  ];
  outputs = [ "out" "wheels" ];
}