.. nix-voyager documentation master file, created by
   sphinx-quickstart on Wed Aug 21 09:20:20 2019.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

Welcome to nix-voyager's documentation!
=======================================

.. toctree::
   :maxdepth: 2
   :caption: Contents:


Motivation
==========

The ``nix-voyager`` project is designed for a very specific use case: you want to use nix, but audit and other team processes require
you to link compiled code against system-maanged dependencies. ``nix-voyager`` lets you get the best of both worlds. You can take advantage
of nix expressions, the hydra build server, and nix channels for package delivery. But at the same time, you can let system administrators
and other team members continue to respond to security vulnerabilities for a given OS/distro by updating the system libraries instead of
having to update them in the nix store.

How does it work?
=================

``nix-voyager`` introduces the concept of a ``builder``, which lets you collect dependencies via nix, run build or install scripts in an isolated
environment, and then export the results back to nix.

Currently all of the builders use ``docker``. Any nix dependencies will be copied into the container and made available to the build scripts.

In the future new builders could be added (e.g. builds inside virtual machines instead of containers), or the tooling could be used
for test execution.

Example: you need the python ``bcrypt`` library in your python app and want a stable way to compile it. You can create a nix expression
using the python wheel builder, specify which system dependencies are required for the build, and it will be compiled against them in a container.
The ``.whl`` file will then be exported out and made available in the nix store. The compiled shared object file will link against the system
``libc``, allowing administrators to update ``libc`` as needed without having to reinstall anything in nix.

Builder APIs
============

mkDockerBuild
-------------

This is a low level builder that can be used to write your own builders. If you have a particular build workflow, e.g. for compiling C or C++ apps,
you can create a builder on top of ``mkDockerBuild``. Your new builder will install all the required build dependencies into the container, provide
a way for the user to pass in build or other scripts, and determine how and where to export the compiled binary and any assets.

mkPythonWheel
-------------

The python wheel builder is used primarily for python wheels with compiled extensions. It allows you to choose which system dependencies and version
of python you want to build against. It then compiles the wheel and makes the ``.whl`` file available to other nix packages.

Example::

  myWheels = mkPythonWheel {
    name = "myapp_dependencies";
    systemPython = "python3.6";
    sources = [
        (fetchurl {
          url = https://files.pythonhosted.org/packages/c2/43/1ae701c9c6bb3a434358e678a5e72c96e8aa55cf4cb1d2fa2041b5dd38b7/pyramid-1.10.4.tar.gz;
          sha256 = "d80ccb8cfa550139b50801591d4ca8a5575334adb493c402fce2312f55d07d66";
        })
    ];
    targetSystemRepos=[ "ppa:deadsnakes/ppa" ];
    extraTargetSystemBuildDependencies = [
        "make"
        "python3.6"
        "gcc"
        "g++"
        "build-essential"
        "python3.6-dev"
        "libpq-dev"
        "zlib1g-dev"
        "libssl-dev"
        "musl-dev"
        "curl"
        "libffi-dev"
        "libsasl2-dev"
        "libldap2-dev"
    ];
  };

Required inputs:

* ``name``: the name of the nix package

* ``sources``: list of nix derivations containing the python source distributions

* ``systemPython``: fully qualified path to the python interpreter we should build with

Optional inputs:

* ``targetSystemRepos``: a list of PPAs or other strings to be added to an apt sources file. e.g. "ppa:deadsnakes/ppa" if you want to use versions of python that don't come with ubuntu

* ``targetSystemAptKeys``: a list of public key IDs from the ubuntu keyserver if you're using any non-PPA repos

* ``extraTargetSystemBuildDependencies``: a list of package names that should be installed on the target system to build the wheel. e.g. "libpq-dev" if you want to build a psycopg2 wheel

mkPythonVirtualenv
------------------


This builder takes one or more python dists (wheels, source dists, etc) and builds a virtualenv against the given virtualenv and python versions.
The end result is a virtualenv that can be copied and installed in different environments, and will be self-contained with respect to its python
dependencies. For its non-python dependencies, the intent is that they will be linked against the system libraries. Note however that this builder
will not recompile any python wheels. It's recommended that you use ``mkPythonWheel`` for compiling any wheels against the target system, rather
than accepting wheels from other sources.

This builder takes the same arguments as `mkPythonWheel`. The main difference is that instead of outputting a wheel file, it outputs a virtualenv
with the wheel already installed.


Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`
