{ callPackage }:
let
  base = callPackage ./base { };
  python = callPackage ./python { };
in
 base // python
