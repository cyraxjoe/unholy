{ unholy ? ../../../. }:
with (import unholy {}).builders;
mkDockerBuild {
  name = "psycopg2";
  unholyExpression = ./build-psycopg2.nix;
  unholyExpressionArgs = {
     virtualEnvSrc = pkgs.fetchurl {
       url = "https://pypi.io/packages/source/v/virtualenv/virtualenv-16.2.0.tar.gz";
       sha256 = "1ka0rlwhcsqkv995jr1xfglhj9d94avbwippxszx52xilwqnhwzs";
     };
  };
  targetSystem = "ubuntu-16.04";
  pruneUntaggedParents = false;
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
