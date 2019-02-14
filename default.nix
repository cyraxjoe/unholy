{ nixpkgs ? null }:
let
   pkgs = import (if nixpkgs == null
                  then  <nixpkgs>
                  else nixpkgs) {};

   callPackage = pkgs.lib.callPackageWith (pkgs // self);

   version = "0.1";

   self = rec {
     inherit callPackage version;

     utils = callPackage ./utils.nix { };

     builders = callPackage ./builders { };
   };
in
  self
