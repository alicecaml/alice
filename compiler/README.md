# Compiler Build

One goal of this project is to avoid representing the compiler as a package. The
compiler will be installed by alternate means and distributed as a binary. This
will be greatly simplified if the compiler is permitted to be installed at
arbitrary paths. Building compiler binaries with this capability is the function
of the scripts in this directory.

For now we'll use an ad-hoc build process for the compiler. Once the
requirements for building the compiler are clearer this can be revisited and
automated in a principled way.

When a non-standard source archive is needed to build a compiler, it will be
hosted in [this](https://git.sr.ht/~gridbugs/spice-compiler-sources) repo.
