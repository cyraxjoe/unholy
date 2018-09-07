{ unholy, nixpkgs }:
with (import unholy { inherit nixpkgs; } ).builders;
let
  jobs = {
     demo = mkBuild {
       name = "Demo";
       script = ''
         echo "test" > $out/test.txt
         echo Joel Rivera
       '';
     };
  };
in
  jobs
