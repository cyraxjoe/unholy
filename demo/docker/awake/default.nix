{ unholySrc ? ../../../. }:
with (import unholySrc {}).builders;
let
  # this test values are irrelevant for awake
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
  name = "awake";
  unholyExpression = ./build-awake.nix;
  unholyExpressionArgs = (testValues // {
     virtualEnvSrc = pkgs.fetchurl {
       url = "https://pypi.io/packages/source/v/virtualenv/virtualenv-16.3.0.tar.gz";
       sha256 = "729f0bcab430e4ef137646805b5b1d8efbb43fe53d4a0f33328624a84a5121f7";
     };
  });
  pruneUntaggedParents = false;
  dockerExec = "/usr/bin/docker";
  targetSystem = "ubuntu-16.04";
  targetSystemBuildDependencies = [
     "python"
  ];

}
