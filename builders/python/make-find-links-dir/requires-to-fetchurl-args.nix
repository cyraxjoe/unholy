{ stdenv, python }:
let
  inherit (stdenv) mkDerivation;
  pythonWithRequests = python.withPackages (ps: [ ps.requests ]);
in
# generate a JSON file with with form:
# { <pkg-name>: { "url": "<full-url-to-pypi-sdist>", "sha256": "<hash>"},
#   ...}
# from a pinned requires file specified as input, there are just a few
# validations, make sure you provide a good requires file with versions
{ requiresFile }:
mkDerivation {
   name = "requires-${ baseNameOf requiresFile}";
   src = requiresFile;
   buildInputs = [ pythonWithRequests ];
   pythonScript = ./requires_to_fetchurl_args.py;
   phases = [ "installPhase" ];
   installPhase = ''
     python $pythonScript $src > $out
   '';
}
