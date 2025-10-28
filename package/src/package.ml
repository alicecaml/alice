open! Alice_stdlib
open Alice_package_meta
open Alice_hierarchy

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
