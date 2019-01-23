{ unholy ? ../../../. }:
with (import unholy {}).builders;
mkDockerBuild {
  name = "awake";
  unholyExpression = ./build-awake.nix;
  targetSystem = "ubuntu-16.04";
  targetSystemBuildDependencies = [
     "python"
  ];
}
