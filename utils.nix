{ }:
let
  inherit (builtins) unsafeDiscardStringContext substring;
in
{
  # this function was _borrowed_ from the toDerivation implementation in nixpkgs
  # to discard the hash part of the filename
  fileNameFromStorePath = path:
    unsafeDiscardStringContext (substring 33 (-1) (baseNameOf path));

  # local reimplementation of 'assertMsg'
  bigErrorMsg = pred: msg:
    if pred
    then true
    else builtins.trace ''

      #########################################################
      ${ msg }
      #########################################################'' false;

}
