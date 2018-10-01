{ pkgs, callPackage }:
let
  base = callPackage ./base { };
  python = callPackage ./python { };
in
 # add a reference for mere convenience for pkgs
 { inherit pkgs; } // base // python
