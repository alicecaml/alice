open! Alice_stdlib

module T = struct
  type t =
    { name : Package_name.t
    ; version : Semantic_version.t
    }

  let to_dyn { name; version } =
    Dyn.record
      [ "name", Package_name.to_dyn name; "version", Semantic_version.to_dyn version ]
  ;;

  let equal t { name; version } =
    Package_name.equal t.name name && Semantic_version.equal t.version version
  ;;

  let compare t { name; version } =
    let open Compare in
    let= () = Package_name.compare t.name name in
    let= () = Semantic_version.compare t.version version in
    0
  ;;
end

include T
module Set = Set.Make (T)
module Map = Map.Make (T)

let name { name; _ } = name
let version { version; _ } = version

let name_dash_version_string { name; version } =
  String.concat
    ~sep:"-"
    [ Package_name.to_string name; Semantic_version.to_string version ]
;;

let name_v_version_string { name; version } =
  sprintf "%s v%s" (Package_name.to_string name) (Semantic_version.to_string version)
;;
