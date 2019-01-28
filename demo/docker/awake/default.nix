{ unholySrc ? ../../../. }:
with (import unholySrc {}).builders;
mkDockerBuild {
  name = "awake";
  unholyExpression = ./build-awake.nix;
  unholyExpressionArgs = {
     falseValue = false;
     trueValue = true;
     nullValue = null;
     emptyStringValue = "";
     zeroValue = 0;
     integerValue = 1560;
     integerAsStringValue = "1000";
     virtualEnvSrc = pkgs.fetchurl {
       url = "https://pypi.io/packages/source/v/virtualenv/virtualenv-16.2.0.tar.gz";
       sha256 = "1ka0rlwhcsqkv995jr1xfglhj9d94avbwippxszx52xilwqnhwzs";
     };
  };
  pruneUntaggedParents = false;
  dockerExec = "/usr/bin/docker";
  targetSystem = "ubuntu-16.04";
  targetSystemBuildDependencies = [
     "python"
  ];

}
