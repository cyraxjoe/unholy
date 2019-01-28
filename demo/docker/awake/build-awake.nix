{ unholySrc
, storePath
# custom arguments
, falseValue
, trueValue
, emptyStringValue
, nullValue
, zeroValue
, integerValue
, integerAsStringValue
, virtualEnvSrc
}:
with (import unholySrc {}).builders;
mkPythonVenvFromPypi {
   name = "awake";
   version = "1.0";
   sha256 = "a4be9058c08ed702b700c9e10e270a7355ba1563f22ad6b2dbd334c6bb5a1730";
   systemPython = "/usr/bin/python2";
   exposedCmds = [ "awake" ];
   logExecution = true;
   inherit storePath virtualEnvSrc;
}
