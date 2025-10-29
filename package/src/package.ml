open! Alice_stdlib
open Alice_package_meta
open Alice_hierarchy
open Alice_error
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
let src_dir_exn t = src_dir_path t |> read_dir_exn
let contains_exe t = File_ops.exists (src_dir_path t / Paths.exe_root_ml)
let contains_lib t = File_ops.exists (src_dir_path t / Paths.lib_root_ml)

module Typed = struct
  type ('exe, 'lib) type_ =
    | Exe_only : (true_t, false_t) type_
    | Lib_only : (false_t, true_t) type_
    | Exe_and_lib : (true_t, true_t) type_

  type nonrec ('exe, 'lib) t =
    { package : t
    ; type_ : ('exe, 'lib) type_
    }

  let limit_to_exe_only : (true_t, true_t) t -> (true_t, false_t) t =
    fun { package; _ } -> { package; type_ = Exe_only }
  ;;

  let limit_to_lib_only : (true_t, true_t) t -> (false_t, true_t) t =
    fun { package; _ } -> { package; type_ = Lib_only }
  ;;

  let package { package; _ } = package
  let type_ { type_; _ } = type_
  let exe_root_ml _ = Paths.exe_root_ml
  let lib_root_ml _ = Paths.lib_root_ml
end

let typed t =
  let package = t in
  match contains_exe package, contains_lib package with
  | false, false ->
    user_exn
      [ Pp.textf
          "Package %S defines contains neither an executable nor a library."
          (Package_id.name_v_version_string (id package))
      ]
  | true, false -> `Exe_only { Typed.package; type_ = Exe_only }
  | false, true -> `Lib_only { Typed.package; type_ = Lib_only }
  | true, true -> `Exe_and_lib { Typed.package; type_ = Exe_and_lib }
;;
