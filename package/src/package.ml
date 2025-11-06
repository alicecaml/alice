open! Alice_stdlib
open Type_bool
open Alice_package_meta
open Alice_hierarchy
open Alice_error
open Alice_io.Read_hierarchy
module File_ops = Alice_io.File_ops

type t =
  { root : Absolute_path.Root_or_non_root.t
  ; meta : Package_meta.t
  }

let to_dyn { root; meta } =
  Dyn.record
    [ "root", Absolute_path.Root_or_non_root.to_dyn root
    ; "meta", Package_meta.to_dyn meta
    ]
;;

let equal t { root; meta } =
  Absolute_path.Root_or_non_root.equal t.root root && Package_meta.equal t.meta meta
;;

let create ~root ~meta = { root; meta }

let read_root root =
  let meta =
    match root with
    | `Root dir_path -> Alice_manifest.read_package_dir ~dir_path
    | `Non_root dir_path -> Alice_manifest.read_package_dir ~dir_path
  in
  create ~root ~meta
;;

let root { root; _ } = root
let meta { meta; _ } = meta
let id { meta; _ } = Package_meta.id meta
let name { meta; _ } = Package_meta.name meta
let version { meta; _ } = Package_meta.version meta
let dependencies { meta; _ } = Package_meta.dependencies meta
let dependency_names t = dependencies t |> Dependencies.names
let exe_root_ml = Basename.of_filename "main.ml"
let lib_root_ml = Basename.of_filename "lib.ml"
let src = Basename.of_filename "src"
let src_dir_path t = Absolute_path.Root_or_non_root.concat_basename (root t) src
let src_dir_exn t = src_dir_path t |> read_dir_exn
let contains_exe t = File_ops.exists (src_dir_path t / exe_root_ml)
let contains_lib t = File_ops.exists (src_dir_path t / lib_root_ml)

module Typed = struct
  type ('exe, 'lib) type_ =
    | Exe_only : (true_t, false_t) type_
    | Lib_only : (false_t, true_t) type_
    | Exe_and_lib : (true_t, true_t) type_

  type nonrec ('exe, 'lib) t =
    { package : t
    ; type_ : ('exe, 'lib) type_
    }

  type lib_only_t = (false_t, true_t) t
  type exe_only_t = (true_t, false_t) t
  type exe_and_lib_t = (true_t, true_t) t

  let to_dyn : type exe lib. (exe, lib) t -> Dyn.t =
    fun { package; type_ } ->
    let type_ =
      match type_ with
      | Exe_only -> "Exe_only"
      | Lib_only -> "Lib_only"
      | Exe_and_lib -> "Exe_and_lib"
    in
    Dyn.record [ "package", to_dyn package; "type_", Dyn.variant type_ [] ]
  ;;

  let equal t { package; type_ = _ } = equal t.package package

  let limit_to_exe_only : (true_t, true_t) t -> (true_t, false_t) t =
    fun { package; _ } -> { package; type_ = Exe_only }
  ;;

  let limit_to_lib_only : (true_t, true_t) t -> (false_t, true_t) t =
    fun { package; _ } -> { package; type_ = Lib_only }
  ;;

  let package { package; _ } = package
  let name t = package t |> name
  let type_ { type_; _ } = type_

  let contains_exe : type exe lib. (exe, lib) t -> exe Type_bool.t =
    fun t ->
    match t.type_ with
    | Exe_only -> True
    | Lib_only -> False
    | Exe_and_lib -> True
  ;;

  let contains_lib : type exe lib. (exe, lib) t -> lib Type_bool.t =
    fun t ->
    match t.type_ with
    | Exe_only -> False
    | Lib_only -> True
    | Exe_and_lib -> True
  ;;
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

type 'a with_typed = { f : 'exe 'lib. ('exe, 'lib) Typed.t -> 'a }

let with_typed with_typed t =
  match typed t with
  | `Exe_only pt -> with_typed.f pt
  | `Lib_only pt -> with_typed.f pt
  | `Exe_and_lib pt -> with_typed.f pt
;;
