# Windows Notes

Windows binary packages are built by hand because they require some manual
intervention. Here's a log of all the errors and workarounds necessary to build
ocamlformat and ocamllsp with dune 3.20.0 on windows.

Building ocamlformat had an error like:
```
Error: entry
_build/.sandbox/a9c066ab7e5bc1e2b31f26febd0d6f73/_private/default/.pkg/ocamlfind/source/src/findlib/ocamlfind
in
_build/.sandbox/a9c066ab7e5bc1e2b31f26febd0d6f73/_private/default/.pkg/ocamlfind/source/ocamlfind.install
does not exist
-> required by _build/_private/default/.pkg/ocamlfind/target/cookie
-> required by Computing closure for package "uuseg"
-> required by library "ocamlformat-lib.parser_standard" in
   _build/default/vendor/parser-standard
```

ocamlfind.install had:
```
bin: [
  "src/findlib/ocamlfind" {"ocamlfind"}
  "?src/findlib/ocamlfind_opt" {"ocamlfind"}
  "?tools/safe_camlp4"
]
toplevel: ["src/findlib/topfind"]
```

Had to change it to:
```
bin: [
  "src/findlib/ocamlfind.exe" {"ocamlfind"}
  "?src/findlib/ocamlfind_opt" {"ocamlfind"}
  "?tools/safe_camlp4"
]
toplevel: ["src/findlib/topfind"]
```

It looks like dune is incorrectly removing the .exe extension which is possibly
correct on unix but not windows. The workaround is to manually add it back.

Next error is:
```
Error: CreateProcess(): Exec format error
-> required by _build/_private/default/.pkg/topkg/target/cookie
-> required by Computing closure for package "uuseg"
-> required by library "ocamlformat-lib.parser_standard" in
   _build/default/vendor/parser-standard
```

This is because the file `.\_build\_private\default\.pkg\ocamlfind\target\bin\ocaml`
is a shell script with a shebang, but that doesn't work on windows.
The workaround is to change build actions like `(run ocaml ...)` with `(run sh
%{pkg:ocamlfind:bin}/ocaml ...)` for all packages that depend on the `ocaml`
shell script from ocamlfind.

Next error was:
```
Running[31]: (cd C:\Users\steph\AppData\Local\Microsoft\Windows\INetCache\dune\git-repo && "C:\Program Files\Git\cmd\git.exe" fetch --no-write-fetch-head https://github.com/alicecaml/ocp-indent 8a43f93ab8b76578e1e74f85ac82bb94164dc7d6) 2> C:\Users\steph\AppData\Local\Temp\dune_8faeb9_run_with_exit_code
File "dune.lock/ocp-indent.1.8.1-no-dynlink.pkg", line 12, characters 7-67:
12 |   (url git+https://github.com/alicecaml/ocp-indent#1.8.1-no-dynlink)))
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Error: failed to extract '8a43f93ab8b76578e1e74f85ac82bb94164dc7d6.tar'
Reason: 'tar.exe' failed with non-zero exit code '2' and output:
- /usr/bin/tar: tests/inplace/link.ml: Cannot create symlink to
  'otherfile.ml': No such file or directory
- /usr/bin/tar: tests/inplace/link2.ml: Cannot create symlink to 'link.ml':
  No such file or directory
- /usr/bin/tar: Exiting with failure status due to previous errors
```

Worked around this by removing all the tests from the ocp-indent package.

Next error was:
```
File "vendor/parser-extended/dune", lines 20-38, characters 0-270:
20 | (menhir
21 |  (infer false)
22 |  (flags
....
36 |   --strategy
37 |   simplified)
38 |  (modules parser))
Error: Program menhir not found in the tree or in PATH
 (context: default)
Hint: opam install menhir
File "vendor/parser-standard/dune", lines 20-38, characters 0-270:
20 | (menhir
21 |  (infer false)
22 |  (flags
....
36 |   --strategy
37 |   simplified)
38 |  (modules parser))
Error: Program menhir not found in the tree or in PATH
 (context: default)
Hint: opam install menhir
```

My guess is its because of the .exe extension on windows. My workaround was to
install menhir with opam.

Next error:
```
File "doc/dune", lines 4-11, characters 0-165:
 4 | (rule
 5 |  (action
 6 |   (with-stdout-to
 7 |    manpage_ocamlformat.mld.gen
 8 |    (run
 9 |     "../tools/gen_manpage/gen_manpage.exe"
10 |     %{bin:ocamlformat}
11 |     --help=plain))))
'..' is not recognized as an internal or external command,
operable program or batch file.
File "doc/dune", lines 19-26, characters 0-171:
19 | (rule
20 |  (action
21 |   (with-stdout-to
22 |    manpage_ocamlformat_rpc.mld.gen
23 |    (run
24 |     ../tools/gen_manpage/gen_manpage.exe
25 |     %{bin:ocamlformat-rpc}
26 |     --help=plain))))
'..' is not recognized as an internal or external command,
operable program or batch file.
```

The workaround was to remove all the custom documentation rules.

Next error:
```
File "dune.lock/ocamlfind.1.9.8+dune.pkg", line 38, characters 10-17:
38 |      (run %{make} all)
               ^^^^^^^
Error: Logs for package ocamlfind
>> Fatal error: Invalid value for the environment variable BUILD_PATH_PREFIX_MAP: invalid key/value pair "D", no '=' separator
Fatal error: exception Misc.Fatal_error
make[1]: *** [Makefile:181: fl_compat.cmo] Error 2
make: *** [Makefile:14: all] Error 2
```

It's happening because the colon-separated `BUILD_PATH_PREFIX_MAP`  environment
variable ends up containing a path beginning with `D:\` which is the name of
the drive where the project and many dev tools are located. Note that the code
in dune that detects this error case and prints the message is vendored into
other packages so we can't fix it by just updating dune's source code.

The workaround was to bypass updating the env in build_path_prefix_map0.ml.
```
diff --git a/src/dune_util/build_path_prefix_map0.ml b/src/dune_util/build_path_prefix_map0.ml
index e7c23b5eb..79739156d 100644
--- a/src/dune_util/build_path_prefix_map0.ml
+++ b/src/dune_util/build_path_prefix_map0.ml
@@ -4,6 +4,7 @@ let _BUILD_PATH_PREFIX_MAP = "BUILD_PATH_PREFIX_MAP"

 let extend_build_path_prefix_map env how map =
   let new_rules = Build_path_prefix_map.encode_map map in
+  let _ =
   Env.update env ~var:_BUILD_PATH_PREFIX_MAP ~f:(function
     | None -> Some new_rules
     | Some existing_rules ->
@@ -11,4 +12,6 @@ let extend_build_path_prefix_map env how map =
         (match how with
          | `Existing_rules_have_precedence -> new_rules ^ ":" ^ existing_rules
          | `New_rules_have_precedence -> existing_rules ^ ":" ^ new_rules))
+  in
+  env
 ;;
```
