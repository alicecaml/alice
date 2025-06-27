open! Alice_stdlib
module Dir = Alice_io.Hierarchy.File.Dir
module C_policy = Alice_policy.C

let () =
  let path = Alice_io.Temp_dir.mkdir ~prefix:"alice." ~suffix:".foo" in
  let _ =
    Alice_io.Fetch.fetch
      ~url:
        "http://localhost:8000/ocamlformat-macos-aarch64.0.27.0-built-with-ocaml.5.3.1+relocatable.tar.gz"
      ~output_file:(Filename.concat path "foo.tar.gz")
  in
  print_endline path
;;
