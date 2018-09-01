{ pkgs ? (import <nixpkgs> {}) }:
let
   callPackage = pkgs.lib.callPackageWith self;
   self = rec {
     inherit pkgs callPackage;
     utils = callPackage ./utils.nix {};
     builders = callPackage ./builders {};
  };
in
  self
