{ ulic ? (import ../default.nix {}) }:
with ulic.builders;
{
  regular = mkBuild {
    allowedSystemCmds = [ "/usr/bin/python3" ];
    buildInputs = with pkgs; [ hello ];
    envVars = {
       name = "Joel Rivera";
    };
    script = ''
      echo "Custom build/derivation!"
      python3 -c "print('test from system python')"
      echo "the content" > $out/content.txt
      echo "more content" >> $out/content.txt
      sleep 3
      echo "more content" >> $out/content.txt
      hello >> $out/content.txt
      echo $ENV_NAME
    '';
  };
}
