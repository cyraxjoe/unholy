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
  };
  pruneUntaggedParents = false;
  dockerExec = "/usr/bin/docker";
  targetSystem = "ubuntu-16.04";
  targetSystemBuildDependencies = [
     "python"
  ];

}
