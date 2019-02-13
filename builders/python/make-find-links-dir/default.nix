{ lib , fetchurl , callPackage , stdenv, utils }:
let
  inherit (builtins) map  attrValues  fromJSON;
  inherit (lib) lists readFile;
  inherit (stdenv) mkDerivation;
  # unholy utils
  inherit (utils) fileNameFromStorePath;
  requiresToFetchUrlArgs = callPackage ./requires-to-fetchurl-args.nix {};
in
# Create a directory with all the source distribution
# of the python dependencies specified in the requiresFile
# argument.
#
# This derivation is meant to have zero dependencies.
{ projectName, requiresFile }:
let
  fetchUrlArgsAsJSON = requiresToFetchUrlArgs { inherit requiresFile; };
  dependenciesFetchUrlArgs = fromJSON (readFile "${ fetchUrlArgsAsJSON }" );
  # list of derivations with the sdist defined in the requiresFile
  dependencies = map (args: fetchurl args) (attrValues dependenciesFetchUrlArgs);
in
mkDerivation {
  name = "find-links-dir-${ projectName }";
  phases = [ "installPhase" ];
  parsedDependencies =
    lists.flatten (map (d: [ d (fileNameFromStorePath d) ])
                        dependencies);
  installPhase = ''
     mkdir -p $out
     echo $parsedDependencies | sed 's/ /\n/g' | {
         while read file_src
         do
             read file_name
             cp $file_src $out/$file_name
         done
     }
  '';
}
