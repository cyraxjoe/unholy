{ nixpkgs ? null }:
let
   pkgs = import (if nixpkgs == null
                  then  <nixpkgs>
                  else nixpkgs) {};
   callPackage = pkgs.lib.callPackageWith (pkgs // self);
   self = rec {
     inherit callPackage;
     utils = callPackage ./utils.nix { };
     builders = callPackage ./builders { };
   };
in
  self
