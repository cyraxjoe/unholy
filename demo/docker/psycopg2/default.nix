{ unholy ? ../../../. }:
with (import unholy {}).builders;
mkDockerBuild {
  name = "psycopg2";
  unholyExpression = ./build-psycopg2.nix;
  targetSystem = "ubuntu-16.04";
  targetSystemBuildDependencies = [
     "build-essential"
     "python-dev"
     "libpq-dev"
  ];
  targetSystemRunDependencies = [
     "python"
     "libpq"
  ];
}
