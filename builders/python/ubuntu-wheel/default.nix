# python wheel builder that compiles extensions against ubuntu 16.04 libraries

{ pkgs , fetchurl, lib , builders }:
let
   inherit (builtins) removeAttrs;
   inherit (lib) lists;
   inherit (lib.attrsets) attrNames;
   ##############################
   inherit (builders) mkDockerBuild;
in
{
# name of the wheel package
  name
# string to be used a prefix to the name,
# if is set to null, then the resulting name
# will be based solely on the `name` parameter
, namePrefix ? "wheel"

# nix input containing the python source distribution
, source

# full path to the python executable in the system, that's
# going to be used to build the virtualenv
, systemPython

}:
mkDockerBuild {
  name = name;

  unholyScript = ./build_wheel.sh;

  inherit systemPython;
  # does this need testValues?
  unholyExpressionArgs = {
    inherit source;
    virtualEnvSrc = pkgs.fetchurl {
      url = https://files.pythonhosted.org/packages/22/e1/ec3567a4471aa812a3fcf85b2f25e1b79a617da8b1f716ea3a9882baf4fb/virtualenv-16.7.3.tar.gz;
      sha256 = "5e4d92f9a36359a745ddb113cabb662e6100e71072a1e566eb6ddfcc95fdb7ed";
    };
  };
  pruneUntaggedParents = false;
  dockerExec = "/usr/bin/docker";
  # this could also be changed
  targetSystem = "ubuntu-16.04";
  # TODO: this should be blank or either a list of commonly required libs.
  # future versions will have this passed in
  targetSystemBuildDependencies = [
     "make"
     "python3.6"
     "gcc"
     "g++"
     "build-essential"
     "python3.6-dev"
     "libpq-dev"
     "zlib1g-dev"
     "libssl-dev"
     "musl-dev"
     "curl"
     "libffi-dev"
     "libsasl2-dev"
     "libldap2-dev"
  ];
  targetSystemRunDependencies = [
  ];
  #outputs = [ "out" "wheels" ];
  outputs = [ "out" ];
  # debug settings
  alwaysRemoveBuildContainers = true;
  keepBuildImage = false;
}


