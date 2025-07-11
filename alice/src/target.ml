open! Alice_stdlib

module Os = struct
  type t =
    | Macos
    | Linux

  let to_dyn = function
    | Macos -> Dyn.variant "Macos" []
    | Linux -> Dyn.variant "Linux" []
  ;;

  let to_string = function
    | Macos -> "macos"
    | Linux -> "linux"
  ;;

  let poll () =
    match Alice_io.Uname.uname_s () with
    | "Darwin" -> Macos
    | "Linux" -> Linux
    | other -> Alice_error.panic [ Pp.textf "Unknown system: %s" other ]
  ;;
end

module Arch = struct
  type t =
    | Aarch64
    | X86_64

  let to_dyn = function
    | Aarch64 -> Dyn.variant "Aarch64" []
    | X86_64 -> Dyn.variant "X86_64" []
  ;;

  let to_string = function
    | Aarch64 -> "aarch64"
    | X86_64 -> "x86_64"
  ;;

  let poll () =
    match Alice_io.Uname.uname_m () with
    | "arm64" -> Aarch64
    | "x86_64" -> X86_64
    | other -> Alice_error.panic [ Pp.textf "Unknown architecture: %s" other ]
  ;;
end

module Linked = struct
  type t =
    | Dynamic
    | Static

  let to_dyn = function
    | Dynamic -> Dyn.variant "Dynamic" []
    | Static -> Dyn.variant "Static" []
  ;;

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

  let to_dyn { os; arch; linked } =
    Dyn.record
      [ "os", Os.to_dyn os; "arch", Arch.to_dyn arch; "linked", Linked.to_dyn linked ]
  ;;

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
  let os = Os.poll () in
  let arch = Arch.poll () in
  let linked =
    match os with
    | Linux ->
      if Alice_io.Infer_linux_distro.current_distro_requires_statically_linked_tools ()
      then Linked.Static
      else Dynamic
    | _ -> Dynamic
  in
  create ~os ~arch ~linked
;;
