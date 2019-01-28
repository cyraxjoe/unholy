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
  };
  pruneUntaggedParents = false;
  dockerExec = "/run/current-system/sw/bin/docker";
  targetSystem = "ubuntu-16.04";
  targetSystemBuildDependencies = [
     "python"
  ];

}
