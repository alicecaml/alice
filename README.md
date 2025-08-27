# Alice the Caml - An OCaml build system experiment

The goal of this project is to explore a radically different approach to OCaml
build systems and package management, breaking from the Opam/Dune-based ecosystem
completely. No attempt will be made to keep compatibility with Opam packages,
though it should be possible to manually port simple packages. The UX is
inspired mostly by Cargo.

Concrete differences from Opam/Dune:
 - No S-expressions or custom metadata formats. TOML only. This avoids the need
   to write custom parser logic, and for editors to understand new syntaxes and
   auto-formatting rules.
 - The OCaml compiler and dev tools are not packages, and will be provided as
   binary downloads, managed by this tool.
 - Packages that build with alice do not depend on alice. This allows alice to
   depend on packages from its own ecosystem (once it's bootstrapped).
 - Users cannot define build rules. alice will know how to compile OCaml and C
   executables and libraries. This lets us keep the config file format simple.
 - Discourage open upper/lower bounds on dependency versions. Packages
   (including ports of Opam packages) will be versioned with semver.
 - Packages will be namespaced with github (and possibly other forge) usernames.
   Anyone can release a package instantly by pushing a tag.
 - Strong opinion about how code is organized. By default code lives in a `src`
   directory, with entry points named `main.ml` or `lib.ml` for executables or
   libraries respectively. These defaults can be overridden, mostly to simplify
   porting. This will make it easy to initialize new projects and to navigate
   the source code of unfamiliar projects.
 - The build/install commands of a package cannot be configured.
 - Packages have the same dependencies regardless of environment.

I'm one of the core Dune developers for my day job. Dune is a mature and widely
used OCaml build system which makes it difficult to make large structural
changes to its UI and packaging philosophy. Alice is an experiment exploring
the design space of OCaml build systems when these constraints are lifted.

Its name comes from an [Australian children's
song](https://www.youtube.com/watch?v=XM7Jnetdf0I).

## Dev Environment Notes

It's recommended to use direnv with the following .envrc while working on this:
```
export PATH=$HOME/.alice/current/bin:$PATH
export DUNE_CONFIG__PORTABLE_LOCK_DIR=enabled
export DUNE_CONFIG__PKG_BUILD_PROGRESS=enabled
```

Run the script in `boot` for your system to bootstrap an environment with the
tools needed to build alice.

### NixOS

On NixOS, use the musl-static builds of the binaries, and add `use nix` to
`.envrc` to install the musl libraries via `shell.nix`.
