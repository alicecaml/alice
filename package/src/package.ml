open! Alice_stdlib
open Alice_package_meta
open Alice_hierarchy
open Alice_io.Read_hierarchy
module File_ops = Alice_io.File_ops

type t =
  { root : Path.Absolute.t
  ; meta : Package_meta.t
  }

let to_dyn { root; meta } =
  Dyn.record [ "root", Path.Absolute.to_dyn root; "meta", Package_meta.to_dyn meta ]
;;

let equal t { root; meta } =
  Path.Absolute.equal t.root root && Package_meta.equal t.meta meta
;;

let create ~root ~meta = { root; meta }

let read_root root =
  let meta = Alice_manifest.read_package_dir ~dir_path:root in
  create ~root ~meta
;;

let root { root; _ } = root
let meta { meta; _ } = meta
let id { meta; _ } = Package_meta.id meta
let name { meta; _ } = Package_meta.name meta
let version { meta; _ } = Package_meta.version meta
let dependencies { meta; _ } = Package_meta.dependencies meta

module Paths = struct
  let src = Path.relative "src"
  let exe_root_ml = Path.relative "main.ml"
  let lib_root_ml = Path.relative "lib.ml"
end

let src_dir_path t = root t / Paths.src
let contains_exe t = File_ops.exists (src_dir_path t / Paths.exe_root_ml)
let contains_lib t = File_ops.exists (src_dir_path t / Paths.lib_root_ml)
let src_dir_exn t = src_dir_path t |> read_dir_exn
let exe_root_ml _ = Paths.exe_root_ml
let lib_root_ml _ = Paths.lib_root_ml
