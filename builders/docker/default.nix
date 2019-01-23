{ callPackage }:
{
  mkDockerBuild = callPackage ./base-builder.nix {};
}
