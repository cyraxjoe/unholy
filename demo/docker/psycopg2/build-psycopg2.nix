{ unholy ? ./., storePath ? "" }:
with (import unholy {}).builders;
mkPythonVenvFromPypi {
   name = "psycopg2";
   version = "2.7.7";
   sha256 = "f4526d078aedd5187d0508aa5f9a01eae6a48a470ed678406da94b4cd6524b7e";
   systemPython = "/usr/bin/python2";
   inherit storePath;
}
