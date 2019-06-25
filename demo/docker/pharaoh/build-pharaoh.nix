{ unholySrc
, storePath ? null
# custom arguments
, falseValue ? false
, trueValue ? true
, emptyStringValue ? ""
, nullValue  ? null
, zeroValue ? 0
, integerValue ? 1
, integerAsStringValue ? "1000"
, virtualEnvSrc ? null
, mainPackageName ? null
, mainPackageSrc ? null
}:
with (import unholySrc {}).builders;

# so this exists potentially outside docker
# meaning docker would need to know how to translate something here,
# like mainPackageSrc, into something in the container...
# in terms of responsibilities, mkPythonVirtualenv should only care
# about receiving a source, whereas the docker builder needs to be
# responsible for carrying it over.
mkPythonVirtualEnv {
   name = "pharaoh-nc";
   systemPython = "/usr/bin/python2";
   exposedCmds = [ ];
   inherit storePath virtualEnvSrc mainPackageName mainPackageSrc;
}