open! Alice_stdlib

module Os = struct
  type t =
    | Macos
    | Linux

  let to_string = function
    | Macos -> "macos"
    | Linux -> "linux"
  ;;

  let poll () =
    match Alice_io.Uname.uname_s () with
    | "Darwin" -> Macos
    | other -> Alice_error.panic [ Pp.textf "Unknown system: %s" other ]
  ;;
end

module Arch = struct
  type t =
    | Aarch64
    | X86_64

  let to_string = function
    | Aarch64 -> "aarch64"
    | X86_64 -> "x86_64"
  ;;

  let poll () =
    match Alice_io.Uname.uname_m () with
    | "arm64" -> Aarch64
    | other -> Alice_error.panic [ Pp.textf "Unknown architecture: %s" other ]
  ;;
end

module Linked = struct
  type t =
    | Dynamic
    | Static

  let to_string = function
    | Dynamic -> "dynamic"
    | Static -> "static"
  ;;
end

module T = struct
  type t =
    { os : Os.t
    ; arch : Arch.t
    ; linked : Linked.t
    }

  let create ~os ~arch ~linked = { os; arch; linked }

  let to_string { os; arch; linked } =
    sprintf "%s-%s-%s" (Os.to_string os) (Arch.to_string arch) (Linked.to_string linked)
  ;;

  let compare a b = String.compare (to_string a) (to_string b)
end

include T
module Map = Map.Make (T)
module Set = Set.Make (T)

let poll () =
  (* TODO: detect whether statically-linked binaries should be used (e.g. on
     Linux if the distro is NixOS or Alpine) *)
  create ~os:(Os.poll ()) ~arch:(Arch.poll ()) ~linked:Dynamic
;;

