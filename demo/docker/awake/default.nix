{ unholySrc ? ../../../. }:
with (import unholySrc {}).builders;
mkDockerBuild {
  name = "awake";
  unholyExpression = ./build-awake.nix;
  pruneUntaggedParents = false;
  dockerExec = "/run/current-system/sw/bin/docker";
  targetSystem = "ubuntu-16.04";
  targetSystemBuildDependencies = [
     "python"
  ];
}
