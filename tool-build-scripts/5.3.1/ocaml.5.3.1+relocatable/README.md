# OCaml 5.3.1 Relocatable

Running shell scripts creates .tar.gz files in this directory. Extracting the
tarball should produce a directory named like
`ocaml-5.3.1+relocatable-aarch64-macos` containing the package contents (e.g.
this directory should contain `bin`, `lib`, `share`, etc.).


## Windows Notes

Configure the source with:
```
sh .\configure --prefix=$PWD\..\ocaml-5.3.1+relocatable-x86_64-windows --with-relative-libdir=../lib/ocaml --enable-runtime-search=always --build=x86_64-w64-mingw32 --enable-imprecise-c99-float-ops
```

- Make sure `C:\msys64\usr\bin` is in PATH so that common commands like `cp`
  and `rm` are available.
- The ocaml compiler source archive doesn't contain flexdll as this is usually
  populated by a git submodule, so manually clone it and check out revision
  3400287999afcdc737f35c1d0e1447c7d2ae5a83.
