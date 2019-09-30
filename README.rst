nix-voyager
===========

The ``nix-voyager`` project is designed for a very specific use case: you want to use nix, but auditing standards and other team processes require
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
