{ nixpkgs ? null }:
let
   pkgs = import (if nixpkgs == null
                  then  <nixpkgs> 
                  else nixpkgs) {};
   callPackage = pkgs.lib.callPackageWith self;
   self = rec {
     inherit pkgs callPackage;
     utils = callPackage ./utils.nix {};
     builders = callPackage ./builders {};
  };
in
  self
